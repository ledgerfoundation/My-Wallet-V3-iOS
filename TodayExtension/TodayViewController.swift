//
//  TodayViewController.swift
//  TodayExtension
//
//  Created by Alex McGregor on 5/26/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import NotificationCenter
import PlatformKit
import PlatformUIKit
import RxDataSources
import RxSwift
import ToolKit
import UIKit

@objc (TodayViewController)
class TodayViewController: UIViewController, NCWidgetProviding {
    
    // MARK: - Types
    
    private typealias RxDataSource = RxTableViewSectionedReloadDataSource<TodayExtensionSectionViewModel>
    
    // MARK: - Private Properties
    
    private static var setupDependencies: Void = {
        // swiftlint:disable trailing_semicolon
        DependencyContainer.defined(by: modules {
            DependencyContainer.today;
            DependencyContainer.toolKit;
            DependencyContainer.networkKit;
            DependencyContainer.platformKit;
        })
        // swiftlint:enable trailing_semicolon
    }()
    
    private let tableView: SelfSizingTableView
    private let presenter: TodayViewPresenter
    private let disposeBag = DisposeBag()
    
    init() {
        _ = Self.setupDependencies
        self.presenter = TodayViewPresenter()
        self.tableView = SelfSizingTableView()
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = UIView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        setupTableView()
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        tableView.layoutToSuperview(axis: .horizontal, usesSafeAreaLayoutGuide: true)
        tableView.layoutToSuperview(axis: .vertical, usesSafeAreaLayoutGuide: true)
        tableView.backgroundColor = UIColor.TodayExtension.background
        tableView.estimatedRowHeight = 56
        tableView.estimatedSectionHeaderHeight = 32
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.rowHeight = UITableView.automaticDimension
        tableView.delegate = self
        tableView.registerNibCell(AssetPriceTableViewCell.self)
        tableView.register(PortfolioTableViewCell.self)
        tableView.register(TodayExtensionSectionHeaderView.self)
        
        let dataSource = RxDataSource(configureCell: { [weak self] _, _, indexPath, item in
            guard let self = self else { return UITableViewCell() }
            let cell: UITableViewCell
            switch item.cellType {
            case .price(let presenter):
                cell = self.assetPriceCell(for: indexPath, presenter: presenter)
            case .portfolio(let presenter):
                cell = self.portfolioCell(for: indexPath, presenter: presenter)
            }
            cell.selectionStyle = .none
            return cell
        })
        
        presenter.sectionObservable
            .bindAndCatch(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
    }
        
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        presenter.refresh()
        DataProvider.default.exchange.refresh()
        completionHandler(NCUpdateResult.newData)
    }
    
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        if activeDisplayMode == .expanded {
            preferredContentSize = tableView.intrinsicContentSize
        } else {
            preferredContentSize = maxSize
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension TodayViewController: UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return presenter.numberOfSections
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeue(TodayExtensionSectionHeaderView.self)
        headerView.viewModel = presenter.viewModel(for: section)
        return headerView
    }
}

extension TodayViewController {
    
    private func portfolioCell(for indexPath: IndexPath, presenter: PortfolioCellPresenter) -> PortfolioTableViewCell {
        let cell = tableView.dequeue(PortfolioTableViewCell.self, for: indexPath)
        cell.presenter = presenter
        return cell
    }
    
    private func assetPriceCell(for indexPath: IndexPath, presenter: AssetPriceCellPresenter) -> AssetPriceTableViewCell {
        let cell = tableView.dequeue(AssetPriceTableViewCell.self, for: indexPath)
        cell.presenter = presenter
        return cell
    }
}

