import UIKit
import RxSwift
import RxCocoa


class TimetableViewController: UIViewController {

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

    // MARK: - Private

    private let timetableService: TimetableService
    private let presenter: TimeTableCellPresenter
    private let timetableFilter: TimetableFiltering

    private func setUpTableViewDataSource() {

        let filter = timetableView.filterView.segmentedControl.rx.selectedSegmentIndex
            .filter { $0 != UISegmentedControl.noSegment }
            .map { Filter.allCases[$0] }

        Observable.combineLatest(filter, timetableService.timetableEntries)
            .map { [weak self] in self?.timetableFilter.apply(filter: $0, for: $1) ?? [] }
            .map { $0.sorted { $0.departureTime < $1.departureTime } }
            .asDriver(onErrorJustReturn: [])
            .drive(timetableView.tableView.rx.items(cellIdentifier: "TimetableCell")) { [weak self] index, model, cell in
                self?.configure(cell: cell, with: model)
            }
            .disposed(by: disposeBag)
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
