//
//  ZXSegmentContainer.swift
//  NestSegment
//
//  Created by paul.yin on 2021/4/24.
//

import UIKit

public protocol ZXSegmentContentItem: AnyObject {
    var itemView: UIView { get }
    var itemViewController: UIViewController? { get }
}

extension UIViewController: ZXSegmentContentItem {
    public var itemView: UIView {
        return self.view
    }
    
    public var itemViewController: UIViewController? {
        return self
    }
}

public protocol ZXSegmentContainerDataSource: AnyObject {
    func numberOfItems(_ container: ZXSegmentContainer) -> Int
    func container(_ container: ZXSegmentContainer, topBarItemFor index: Int) -> ZXSegmentBarItem
    /** 提供每项显示的内容，仅支持UIView和UIViewController两种类型，每次reload该方法对每个index只会调用一次 */
    func container(_ container: ZXSegmentContainer, contentItemFor index: Int) -> ZXSegmentContentItem
}

public protocol ZXSegmentContainerDelegate: NSObjectProtocol {
    func containerDidReload(_ container: ZXSegmentContainer)
    func container(_ container: ZXSegmentContainer, didDeselectItemAt index: Int, type: ZXSegmentContainer.SwitchType)
    func container(_ container: ZXSegmentContainer, didSelectItemAt index: Int, type: ZXSegmentContainer.SwitchType)
}

extension ZXSegmentContainerDelegate {
    public func containerDidReload(_ container: ZXSegmentContainer) {}
    public func container(_ container: ZXSegmentContainer, didDeselectItemAt index: Int, type: ZXSegmentContainer.SwitchType) {}
    public func container(_ container: ZXSegmentContainer, didSelectItemAt index: Int, type: ZXSegmentContainer.SwitchType) {}
}

public protocol YFScrollToTopProtocol: AnyObject {
    /** 在包含scrollView的UIView或UIViewController中，设置scrollView的scrollToTop特性 */
    func setScrollToTop(_ scrollToTop: Bool)
}

open class ZXSegmentScrollView: UIScrollView {
    
    public var enablePopGesture: Bool = true //是否支持识别UIViewController的popGesture
    public var enablePanGuesture: Bool = true //是否支持识别手势PanGuesture
    
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        guard enablePanGuesture else { return false }
        guard enablePopGesture, gestureRecognizer == self.panGestureRecognizer else { return true }
        let location = gestureRecognizer.location(in: self)
        return location.x > 50
    }
}

public class ZXSegmentContainer: UIView {
    
    //other指点击和滑动之外的切换方式，如：reload，或调用selectItem
    public enum SwitchType {
        case click, slide, other
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setupView()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        if !isLoaded {
            isLoaded = true
            self.reload()
        } else {
            //do nothing
        }
    }
    
    func setupView() {
        self.addSubview(topBar)
        self.addSubview(contentView)
        
        self.refreshLayout()
    }
    
    func refreshLayout() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        let metrics = ["barHeight": topBarHeight]
        let viewDic: [String: UIView] = ["topBar": topBar, "contentView": contentView]
        
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[topBar]|", options: [], metrics: metrics, views: viewDic))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[contentView]|", options: [], metrics: metrics, views: viewDic))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[topBar(==barHeight)][contentView]|", options: .alignAllCenterX, metrics: metrics, views: viewDic))
        
        if self.superview != nil {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    
    
    //MARK: Public
    public func contentItemAtIndex(index: Int) -> AnyObject? {
        return contentItemCache[index]
    }
    
    public func selectItem(at index: Int, animated: Bool) {
        guard index != currentIndex else { return }
        
        if isLoaded {
            switchToIndex(index: index, fromIndex: currentIndex, type: .other, animated: animated)
        } else {
            currentIndex = max(0, index)
        }
    }
    
    
    //MARK: Properties
    public var selectedIndex: Int {
        return currentIndex
    }
    
    public weak var parentVC: UIViewController?
    public weak var delegate: ZXSegmentContainerDelegate?
    public weak var dataSource: ZXSegmentContainerDataSource?
    
    public var topBarHeight: CGFloat = 45.0 {
        didSet {
            removeConstraints(constraints)
            refreshLayout()
        }
    }

    private var isLoaded = false
    private var userDragging = false //用户当前是否正在滑动
    
    private var currentIndex = 0
    private var totalItemCount = 0
    
    private var contentItemCache = [Int: AnyObject]()
    
    //是否禁止切换
    public var disableSwitch: Bool = false {
        didSet {
            if disableSwitch {
                topBar.isUserInteractionEnabled = false
                contentView.isScrollEnabled = false
            } else {
                topBar.isUserInteractionEnabled = true
                contentView.isScrollEnabled = true
            }
        }
    }
    
    public var enablePanGuesture: Bool = true {
        
        didSet {
            contentView.enablePanGuesture = enablePanGuesture
        }
    }
    
    //在reload时，将所有页面进行预加载，避免左右滑动时出现空白页，页面较多时慎用
    public var preloadAllPage: Bool = false
    
    //是否支持UIViewController的popGesture
    public var recogizePopGesture: Bool = true {
        didSet {
            self.topBar.recogizePopGesture = recogizePopGesture
            self.contentView.enablePopGesture = recogizePopGesture
        }
    }
    
    public lazy var topBar: ZXSegmentBar = {
        let bar = ZXSegmentBar()
        bar.delegate = self
        return bar
    }()
    
    public lazy var contentView: ZXSegmentScrollView = {
        let scrollView = ZXSegmentScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isPagingEnabled = true
        scrollView.delegate = self
        scrollView.scrollsToTop = false
        return scrollView
    }()
}


//MARK: Reload
extension ZXSegmentContainer {
    
    public func reload() {
        
        guard let ds = dataSource, isLoaded else { return }
        
        totalItemCount = ds.numberOfItems(self)
        
        topBar.reload()
        reloadContent()
        preloadingAllPageIfNeed()
        switchToIndex(index: currentIndex, fromIndex: nil, type: .other, animated: false)
        delegate?.containerDidReload(self)
    }
    
    private func reloadContent() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        contentItemCache.values.forEach {
            guard let vc = $0 as? UIViewController, vc.parent != nil else { return }
            vc.willMove(toParent: nil)
            vc.removeFromParent()
        }
        contentItemCache.removeAll()
        
        let helpView = UIView()
        helpView.backgroundColor = UIColor.clear
        contentView.addSubview(helpView)
        
        helpView.translatesAutoresizingMaskIntoConstraints = false
        let metrics = ["contentWidth": contentView.bounds.width * CGFloat(totalItemCount)]
        let viewDic: [String: UIView] = ["helpView": helpView]
        
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[helpView(==contentWidth)]|", options: [], metrics: metrics, views: viewDic))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[helpView]|", options: [], metrics: metrics, views: viewDic))
        contentView.addConstraint(NSLayoutConstraint(item: helpView, attribute: .height, relatedBy: .equal, toItem: contentView, attribute: .height, multiplier: 1.0, constant: 0))
    }
    
    private func preloadingAllPageIfNeed() {
        guard preloadAllPage else { return }
        
        for index in 0..<totalItemCount {
            configContent(atIndex: index)
        }
    }
}

//MARK: Switch
extension ZXSegmentContainer {
    
    private func switchToIndex(index: Int, fromIndex: Int?, type: ZXSegmentContainer.SwitchType, animated: Bool) {
        guard index < totalItemCount && index >= 0 else { return }
        
        self.configContent(atIndex: index)
        
        if let scrollViewItem = contentItemCache[index] as? YFScrollToTopProtocol {
            scrollViewItem.setScrollToTop(true)
        } else {
            layoutIfNeeded()
        }
        
        if let preIndex = fromIndex {
            if let scrollViewItem = contentItemCache[preIndex] as? YFScrollToTopProtocol {
                scrollViewItem.setScrollToTop(false)
            }
        }
        
        currentIndex = index
        self.switchContentToIndex(index: index, animated: animated)
        
        if type != .click {
            topBar.selectItem(at: index, animated: animated)
        }
        
        if let deselectIndex = fromIndex {
            delegate?.container(self, didDeselectItemAt: deselectIndex, type: type)
        }
        
        delegate?.container(self, didSelectItemAt: index, type: type)
    }
    
    private func switchContentToIndex(index: Int, animated: Bool) {
        let offsetX = contentView.bounds.size.width * CGFloat(index)
        //动画期间设置userInteractionEnabled为false会导致tableViewCell高度状态无法消除等未问题，故去掉该配置。
        if animated {
            UIView.animate(withDuration: 0.25, animations: {
                self.contentView.contentOffset = CGPoint(x: offsetX, y: 0)
            })
        } else {
            self.contentView.contentOffset = CGPoint(x: offsetX, y: 0)
        }
    }
    
    private func configContent(atIndex index: Int) {
        
        guard let ds = dataSource, contentItemCache[index] == nil else { return }
        
        let item = ds.container(self, contentItemFor: index)
        let itemView = item.itemView
        
        if let itemVC = item.itemViewController {
            //在vc加载时，将其添加到parentVC，不在每次切换时进行添加和移除
            parentVC?.addChild(itemVC)
            itemVC.didMove(toParent: parentVC)
        } else {
            //do nothing
        }
        
        contentItemCache.updateValue(item, forKey: index)
        
        contentView.addSubview(itemView)
        
        itemView.translatesAutoresizingMaskIntoConstraints = false
        let viewDic: [String: UIView] = ["itemView": itemView]
        
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[itemView]|", options: [], metrics: nil, views: viewDic))
        contentView.addConstraint(NSLayoutConstraint(item: itemView, attribute: .left, relatedBy: .equal, toItem: contentView, attribute: .left, multiplier: 1.0, constant: CGFloat(index) * contentView.bounds.width))
        contentView.addConstraint(NSLayoutConstraint(item: itemView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: contentView.bounds.width))
    }
}

//MARK: SegmentTopBarDelegate
extension ZXSegmentContainer: ZXSegmentBarDelegate {
    
    public func numberOfItems(_ bar: ZXSegmentBar) -> Int {
        return dataSource?.numberOfItems(self) ?? 0
    }
    
    public func segmentBar(_ bar: ZXSegmentBar, itemForIndex index: Int) -> ZXSegmentBarItem {
        return dataSource?.container(self, topBarItemFor: index) ?? UIControl()
    }
    
    public func segmentBar(_ bar: ZXSegmentBar, didClickItemAtIndex index: Int) {
        guard index != currentIndex else { return }
        switchToIndex(index: index, fromIndex: currentIndex, type: .click, animated: bar.enableClickAnimation)
    }
    
    public func segmentBar(_ bar: ZXSegmentBar, shouldClickItemAtIndex index: Int) -> Bool {
        return index != bar.selectedIndex && index < bar.itemCache.count && index >= 0
    }
    
}

//MARK: UIScrollViewDelegate
extension ZXSegmentContainer: UIScrollViewDelegate {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if userDragging {
            let distance: CGFloat = scrollView.contentOffset.x - CGFloat(currentIndex) * scrollView.bounds.size.width
            topBar.updateIndicatorPosition(distance, scrollView.bounds.size.width)
        }
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        userDragging = true
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        userDragging = decelerate
        if userDragging == false {
            scrollViewDidEndMoving(scrollView)
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        userDragging = false
        scrollViewDidEndMoving(scrollView)
    }
    
    private func scrollViewDidEndMoving(_ scrollView: UIScrollView) {
        let offsetX = scrollView.contentOffset.x
        let index = Int(offsetX / scrollView.bounds.size.width)
        if index != currentIndex {
            switchToIndex(index: index, fromIndex: currentIndex, type: .slide, animated: true)
        } else {
            
        }
    }
}
