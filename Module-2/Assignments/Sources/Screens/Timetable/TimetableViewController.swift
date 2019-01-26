import UIKit
import RxSwift
import RxCocoa


class TimetableViewController: UIViewController, UITableViewDataSource { // TODO_2_DELETE: Usuń `UITableViewDataSource`

    private let disposeBag = DisposeBag()

    init(timetableService: TimetableService = LocalFileTimetableService(),
         presenter: TimeTableCellPresenter = TimeTableCellPresenter(),
         filter: TimetableFiltering = TimetableFilter()) {
        self.timetableService = timetableService
        self.presenter = presenter
        self.timetableFilter = filter

        super.init(nibName: nil, bundle: nil)
    }

    var timetableView: TimetableView! {
        return view as? TimetableView
    }

    let refreshControl = UIRefreshControl(frame: .zero)

    // MARK: - Lifecycle

    override func loadView() {
        view = TimetableView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Timetable"
        setUpSegments()
        selectFirstSegment()
        setUpTableViewDataSource()
        setUpRefreshControl()
    }

    // TODO_2_DELETE: Usuń `MARK - UITableViewDataSource` wraz z całym kodem poniżej do `MARK - Private`

    // MARK: - UITableViewDataSource

    private func update(filter: Filter, entries: [TimetableEntry]) {
        allEntries = entries
        filteredEntries = timetableFilter.apply(filter: filter, for: entries)
    }

    private var allEntries: [TimetableEntry] = []

    private var filteredEntries: [TimetableEntry] = [] {
        didSet {
            timetableView.tableView.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredEntries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TimetableCell",
                                                       for: indexPath) as? TimetableEntryCell else {
            fatalError("Could NOT dequeue cell for TimetableCell identifier")
        }

        let model = filteredEntries[indexPath.row]
        configure(cell: cell, with: model)
        return cell
    }

    // MARK: - Private

    private let timetableService: TimetableService
    private let presenter: TimeTableCellPresenter
    private let timetableFilter: TimetableFiltering

    // TODO_2:
    // 1. Usuń całą implementację funkcji oznaczonej komentarzem `TODO_2_REPLACE`
    // 2. Zastąp bieżącą implementację metody setUpTableViewDataSource() rx'owym bindingiem:
    //   a. wykorzystaj strumień timetableEntries pochodzący z zależności timetableService
    //   b. znajdź sposób na połączenia strumienia a. ze zmianą filtru w segmented control
    //      (podpowiedź: kod napisałeś już w ramach TODO_1)
    //   c. wynikowy strumień podepnij do table view używając właściwości rx.items na UITableView
    //   d. nie zapomnij obsłużyć potencjalnego błędu (może on pochodzić np. ze strumienia timetableEntries) -
    //      przekształć błąd w pustą tablicę
    // 3. Zweryfikuj poprawność refactoringu uruchamiając testy jednostkowe

    private func setUpTableViewDataSource() { // TODO_2_REPLACE: Zastąp implementację funkcji
        timetableView.tableView.dataSource = self

        timetableService.fetch(completion: { [unowned self] entries in
            let filter = Filter.allCases[self.timetableView.filterView.segmentedControl.selectedSegmentIndex]
            let entries = entries.sorted { $0.departureTime < $1.departureTime }

            self.update(filter: filter, entries: entries)
        })
    }

    private func configure(cell: TimetableEntryCell, with entry: TimetableEntry) {
        presenter.present(model: entry, in: cell)

        // TODO_3:
        // 1. Usuń fragment kodu oznaczony komentarzem `TODO_3_DELETE`.
        // 2. Zastąp wywołanie closure'a rx'owym obsłużeniem tapnięcia na przycisk:
        //   a. zastanów się co stanie się jeśli subskrypcja zostanie przypięta do dispose baga wewnątrz controllera
        //   b. rozwiąż problem zdiagnozowany w punkcie a. - do tego celu przenalizuj implementację funkcji
        //      prepareForReuse() wewnątrz klasy TimetableEntryCell
        // 3. Zweryfikuj poprawność refactoringu uruchamiając testy jednostkowe

        cell.didTapCheckInButton = { [weak self] in // TODO_3_DELETE: Usuń cały closure
            self?.pushCheckInViewController(timetableID: entry.id)
        }
    }

    private func pushCheckInViewController(timetableID: Int) {
        let checkInController = CheckInViewController(timetableID: timetableID)
        pushController?(checkInController, true)
    }

    // MARK: Filter view

    private func setUpSegments() {

        timetableView.filterView.segmentedControl.rx.selectedSegmentIndex
            .filter { $0 != UISegmentedControl.noSegment }
            .map { Filter.allCases[$0] }
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                self.update(filter: $0, entries: self.allEntries)
            })
            .disposed(by: disposeBag)

        Filter.allCases.enumerated().forEach { index, filter in
            let segmentedControl = timetableView.filterView.segmentedControl
            segmentedControl.insertSegment(withTitle: filter.rawValue, at: index, animated: false)
        }
    }

    private func selectFirstSegment() {
        timetableView.filterView.segmentedControl.selectedSegmentIndex = 0
    }

    private func setUpRefreshControl() {
        timetableView.tableView.refreshControl = refreshControl
    }

    // MARK: Helpers

    lazy var pushController: ((UIViewController, Bool) -> Void)? = navigationController?.pushViewController(_:animated:)

    // MARK: Required initializer

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

}
