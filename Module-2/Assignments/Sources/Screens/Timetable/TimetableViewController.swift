import UIKit
import RxSwift
import RxCocoa
import RxSwiftUtilities


class TimetableViewController: UIViewController {

    private let disposeBag = DisposeBag()

    init(timetableService: TimetableService = HTTPTimetableService(),
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

    private lazy var activityIndicator: ActivityIndicator = {
        let activityIndicator = ActivityIndicator()
        activityIndicator.asDriver().drive(UIApplication.shared.rx.progress)
            .disposed(by: disposeBag)
        return activityIndicator
    }()

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

    private lazy var selectedFilter = {
        timetableView.filterView.segmentedControl.rx.selectedSegmentIndex
            .filter { $0 != UISegmentedControl.noSegment }
            .map { Filter.allCases[$0] }
    }()

    private lazy var fileteredTimetableEntries: Driver<[TimetableEntry]> = {
        let timetableEntries = refreshControl.rx.controlEvent(.valueChanged).asObservable().startWith(())
            .flatMapFirst { [unowned self] in
                self.timetableService.timetableEntries
                    .trackActivity(self.activityIndicator)
        }
        return Observable.combineLatest(selectedFilter, timetableEntries)
            .map { [weak self] in self?.timetableFilter.apply(filter: $0, for: $1) ?? [] }
            .map { $0.sorted { $0.departureTime < $1.departureTime } }
            .asDriver(onErrorJustReturn: [])
    }()

    private func setUpTableViewDataSource() {

        fileteredTimetableEntries
            .drive(timetableView.tableView.rx.items(cellIdentifier: "TimetableCell")) { [weak self] index, model, cell in
                self?.configure(cell: cell, with: model)
            }
            .disposed(by: disposeBag)
    }

    private func configure(cell: TimetableEntryCell, with entry: TimetableEntry) {
        presenter.present(model: entry, in: cell)

        cell.checkInButton.rx.tap.subscribe(onNext: { [weak self] in
            self?.pushCheckInViewController(timetableID: entry.id)
        }).disposed(by: cell.disposeBag)
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

        fileteredTimetableEntries
            .drive(onNext: { [refreshControl] _ in refreshControl.endRefreshing() })
            .disposed(by: disposeBag)
    }

    // MARK: Helpers

    lazy var pushController: ((UIViewController, Bool) -> Void)? = navigationController?.pushViewController(_:animated:)

    // MARK: Required initializer

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

}
