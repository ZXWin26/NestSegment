//
//  ZXNestSegmentContainer+Header.swift
//  NestSegment
//
//  Created by paul.yin on 2021/4/24.
//

import Foundation
import SnapKit

/// ZXNestSegmentContainer配置HeaderView
public protocol ZXNestSegmentContainerHeaderConfig {
    func configHeader(view: UIView)
    func configHeader(vc: UIViewController)
    
    func configHeader(scrollView: UIScrollView)
    func configHeader(listVC: ZXScrollViewController)
}

private var kHeightConstraintKey: UInt8 = 0

extension ZXNestSegmentContainer: ZXNestSegmentContainerHeaderConfig {
    
    public func configHeader(vc: UIViewController) {
        parentVC?.addChild(vc)
        vc.loadViewIfNeeded()
        configHeader(view: vc.view)
    }
    
    public func configHeader(view: UIView) {
        headerView.subviews.forEach { $0.removeFromSuperview() }
        headerHeightObservation = nil
        headerView.addSubview(view)
        view.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    public func configHeader(listVC: ZXScrollViewController) {
        parentVC?.addChild(listVC)
        listVC.loadViewIfNeeded()
        configHeader(scrollView: listVC.scrollView)
    }
    
    public func configHeader(scrollView: UIScrollView) {
        headerView.subviews.forEach { $0.removeFromSuperview() }
        headerHeightObservation = nil
        headerView.addSubview(scrollView)
        scrollView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
            make.size.equalTo(scrollView.frame.size)
        }
        
        scrollView.isScrollEnabled = false
        headerHeightObservation = scrollView.observe(\.contentSize, options: [.old, .new]) { [weak self] (tableView, change) in
            guard let strongSelf = self else {return}
            scrollView.snp.remakeConstraints { (make) in
                make.edges.equalToSuperview()
                make.height.equalTo(change.newValue?.height ?? 0)
            }
            strongSelf.refreshCurrentContentSize()
        }
    }
    
    private var headerHeightObservation: NSKeyValueObservation? {
        get {
            let constraint = objc_getAssociatedObject(self, &kHeightConstraintKey) as? NSKeyValueObservation
            return constraint
        }
        set {
            objc_setAssociatedObject(self, &kHeightConstraintKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
