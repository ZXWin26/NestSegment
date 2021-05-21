//
//  ZXNestSegmentContainer.swift
//  NestSegment
//
//  Created by paul.yin on 2021/4/24.
//

import Foundation
import SnapKit

private var kDidScrollClosureKey = 0

@objc public extension UIScrollView {
    @objc var yf_didScrollClosure: ((UIScrollView)->())? {
        get {
            return objc_getAssociatedObject(self, &kDidScrollClosureKey) as? ((UIScrollView)->())
        }
        set(newValue) {
            objc_setAssociatedObject(self, &kDidScrollClosureKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

@objc public protocol ZXScrollViewController where Self: UIViewController {
    @objc var scrollView: UIScrollView { get }
}

@objc public protocol ZXSegmentContentViewController: ZXScrollViewController {
    /// UIViewController为非纯列表视图时，固定高度部分使用fixedHeight
    @objc optional var fixedHeight: CGFloat {get}
    
    @objc optional var mode: ZXNestSegmentContainer.SublistHeightMode {get}
    
    // 兼容异常场景的高度, mode为contentHeight时使用
    @objc optional var unexpectedHeight: CGFloat {get}
}

open class ZXNestSegmentContainer: ZXSegmentScrollView, UIGestureRecognizerDelegate {
    
    /// 子视图不满一屏时展示模式
    @objc public enum SublistHeightMode: Int {
        case fixed // 跟随segmentContainer固定高度
        case contentHeight // 跟随contentSize.height动态高度
    }
    
    @objc public init(parentVC: UIViewController) {
        super.init(frame: .zero)
        
        self.parentVC = parentVC
        setupSubview()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setupSubview() {
        addSubview(headerView)
        addSubview(container)
        addSubview(contentHeightView)
        
        headerView.snp.makeConstraints { (make) in
            make.top.left.equalToSuperview()
            make.width.equalToSuperview()
        }
        container.snp.makeConstraints { (make) in
            self.barTopConstraint = make.top.equalTo(headerView.snp.bottom).constraint
            make.left.right.equalTo(headerView)
            make.height.equalToSuperview()
        }
        contentHeightView.snp.makeConstraints { (make) in
            make.left.bottom.top.equalToSuperview()
            self.contentHeightConstraint = make.height.equalTo(0).constraint
        }
    }
    
    open override var contentOffset: CGPoint {
        didSet {
            let headerHeight = headerView.bounds.height
            let sublistOffsetY = contentOffset.y - headerHeight
            
            if sublistOffsetY >= 0 {
                currentContentVC?.scrollView.contentOffset.y = sublistOffsetY
                barTopConstraint?.update(offset: sublistOffsetY)
            } else {
                barTopConstraint?.update(offset: 0)
                sublistScrollToTop()
            }
        }
    }
    
    func sublistScrollToTop() {
        let itemCount = segmentDataSource?.numberOfItems(container) ?? 0
        for index in 0..<itemCount {
            let itemVC = segmentDataSource?.container(container, contentItemFor: index).itemViewController
            if let vc = itemVC?.itemViewController as? ZXSegmentContentViewController, vc.isViewLoaded {
                vc.scrollView.contentOffset.y = 0
            }
        }
    }
    
    public func reload() {
        
        container.reload()
        
    }
    
    /// 主动刷新contentSize，当前子视图非ZXSegmentContentViewController时，不处理
    func refreshCurrentContentSize() {
        let currentVC = segmentDataSource?.container(container, contentItemFor: container.selectedIndex).itemViewController
        
        guard let vc = currentVC as? ZXSegmentContentViewController else {
            
            let originalY = contentOffset.y
            contentInset.bottom = 0
            contentOffset.y = originalY
            refreshContentSize(subListContentSize: currentVC?.view.bounds.size ?? .zero)
            return
        }
        refreshContentSize(contentVC: vc)
    }
    
    /// 切换Tab刷新contentSize
    private func refreshContentSize(subListContentSize: CGSize) {
        
        let totalHeight = subListContentSize.height + headerView.bounds.height + container.topBarHeight
        
        contentHeightConstraint?.update(offset: totalHeight)
    }
    
    @objc private func tabAnimation(contentHeight: NSNumber) {
        let maxOffset = CGFloat(contentHeight.doubleValue) + self.headerView.bounds.height + self.container.topBarHeight - self.bounds.height
        UIView.animate(withDuration: 0.2) {
            self.contentOffset = CGPoint(x: 0, y: max(0, maxOffset))
        } completion: { (res) in
            self.refreshContentSize(subListContentSize: CGSize(width: self.pageWidth, height: CGFloat(contentHeight.doubleValue)))
        }
    }
    
    private func refreshContentSize(contentVC: ZXSegmentContentViewController) {
        
        updateingContentSize = true
        
        var height = contentVC.view.bounds.height
        var contentHeight = contentVC.scrollView.contentSize.height + (contentVC.fixedHeight ?? 0)
        
        var mode = sublistMode
        if let vcMode = contentVC.mode {
            mode = vcMode
        }
        
        switch mode {
        case .fixed where contentHeight <= height: break
        case .contentHeight where contentHeight <= height:
            if contentVC.scrollView.contentSize.height < 50 {
                contentHeight = contentVC.unexpectedHeight ?? contentHeight
            }
            
            let maxOffset = max(contentHeight + self.headerView.bounds.height + self.container.topBarHeight - self.bounds.height, 0)

            if contentOffset.y > maxOffset {
                
                ZXNestSegmentContainer.cancelPreviousPerformRequests(withTarget: self)
                perform(#selector(tabAnimation(contentHeight:)), with: NSNumber.init(value: Double(contentHeight)), afterDelay: 0)
                
            } else {
                height = contentHeight
            }
        default:
            height = contentHeight
        }
        
        
        
        refreshContentSize(subListContentSize: CGSize(width: contentVC.scrollView.contentSize.width, height: height))
    }
    
    /// 切换Tab刷新contentOffset
    private func refreshContentOffset(subListContentOffset: CGPoint) {
        
        guard subListContentOffset != .zero else {
            if contentOffset.y > headerView.bounds.height {
                contentOffset.y = headerView.bounds.height
            }
            return
        }
        
        contentOffset.y = headerView.bounds.height + subListContentOffset.y
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        // 当前视图非ZXSegmentContentViewController时
        // 首次加载界面，尚未完成layout会导致ContentSize计算错误，
        if currentContentVC == nil {
            refreshContentSize(subListContentSize: container.contentView.bounds.size)
        }
    }
    
    open override func responds(to aSelector: Selector!) -> Bool {
        
        let respond = super.responds(to: aSelector)
        if respond {
            return true
        }
        
        return segmentDelegate?.responds(to: aSelector) ?? false
    }
    
    open override class func resolveInstanceMethod(_ sel: Selector!) -> Bool {
        return true
    }
    
    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        return segmentDelegate
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer == currentContentVC?.scrollView.panGestureRecognizer {
            return true
        }
        return false
    }
    
    public var topBarHeight: CGFloat {
        set {
            container.topBarHeight = newValue
            container.snp.remakeConstraints { (make) in
                self.barTopConstraint = make.top.equalTo(headerView.snp.bottom).constraint
                make.left.right.equalTo(headerView)
                make.height.equalToSuperview()
            }
            layoutIfNeeded()
        }
        get {
            container.topBarHeight
        }
    }
    
    
    /// 子视图不满一屏时展示模式
    public var sublistMode: SublistHeightMode = .contentHeight
    
    /// 当前子列表Controller
    private var currentContentVC: ZXSegmentContentViewController?
    
    /// SegmentBar位置约束
    private var barTopConstraint: Constraint?
    
    /// 调整ContentSize高度约束
    private var contentHeightConstraint: Constraint?
    
    private var contentOffsetObserve: NSKeyValueObservation?
    
    private var sublistContentSizeObserve: NSKeyValueObservation?
    
    private var sublistContentInsetObserve: NSKeyValueObservation?
    
    public var pageWidth: CGFloat {
        bounds.width
    }
    
    private var updateingContentSize: Bool = false
    
    public weak var segmentDelegate: ZXSegmentContainerDelegate?
    
    public var segmentDataSource: ZXSegmentContainerDataSource? {
        get {
            container.dataSource
        }
        set {
            container.dataSource = newValue
        }
    }
    
    internal var parentVC: UIViewController? {
        get {
            container.parentVC
        }
        set {
            container.parentVC = newValue
        }
    }
    
    public lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    //MARK: property
    public lazy var container: ZXSegmentContainer = {
        let v = ZXSegmentContainer()
        v.delegate = self
        v.topBar.bottomLineHeight = 0.5
        v.topBar.bottomLineView.backgroundColor = UIColor.red
        return v
    }()
    
    private lazy var contentHeightView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
}

extension ZXNestSegmentContainer: ZXSegmentContainerDelegate {
    public func container(_ container: ZXSegmentContainer, didSelectItemAt index: Int, type: ZXSegmentContainer.SwitchType) {
        
        sublistContentSizeObserve = nil
        sublistContentInsetObserve = nil

        let currentVC = segmentDataSource?.container(container, contentItemFor: index).itemViewController
        
        guard let contentVC = currentVC as? ZXSegmentContentViewController else {
            
            let originalY = contentOffset.y
            contentInset.bottom = 0
            contentOffset.y = originalY
            refreshContentSize(subListContentSize: currentVC?.view.bounds.size ?? .zero)
            refreshContentOffset(subListContentOffset: .zero)
            return
        }
        
        currentContentVC = contentVC
        currentContentVC?.scrollView.showsVerticalScrollIndicator = false
        currentContentVC?.scrollView.yf_didScrollClosure = { [weak self] (scrollView) in
            guard let strongSelf = self, !strongSelf.updateingContentSize else {
                self?
                    .updateingContentSize = false
                return
                
            }
            
            let headerHeight = strongSelf.headerView.bounds.height
            let sublistOffsetY = strongSelf.contentOffset.y - headerHeight

            if sublistOffsetY >= 0 {
                scrollView.contentOffset.y = sublistOffsetY
            } else {
                scrollView.contentOffset.y = 0
            }
        }
        
        sublistContentSizeObserve = contentVC.scrollView.observe(\.contentSize, options: [.old, .new]) { [weak self] (scrollView, change) in
            guard let strongSelf = self, change.oldValue != change.newValue else { return }
            
            // 父scrollView同步子scrollView ContentSize
            strongSelf.refreshContentSize(contentVC: contentVC)
        }
        
        sublistContentInsetObserve = contentVC.scrollView.observe(\.contentInset, options: [.old, .new]) { [weak self] (scrollView, change) in
            guard let strongSelf = self, change.oldValue != change.newValue else { return }
            
            // 父scrollView同步子scrollView ContentSize
            let originalOffset = contentVC.scrollView.contentOffset
            strongSelf.contentInset.bottom = contentVC.scrollView.contentInset.bottom
            strongSelf.refreshContentOffset(subListContentOffset: originalOffset)
        }
        
        let originalOffset = contentVC.scrollView.contentOffset
        contentInset.bottom = contentVC.scrollView.contentInset.bottom
        refreshContentSize(contentVC: contentVC)
        refreshContentOffset(subListContentOffset: originalOffset)
        
        segmentDelegate?.container(container, didSelectItemAt: index, type: type)
    }

    
}
