//
//  YFSegmentBar.swift
//  ReOrientWM
//
//  Created by zagger on 07/08/2017.
//  Copyright © 2017 RuiFuTech. All rights reserved.
//

import UIKit
import SnapKit

public protocol ZXSegmentBarDelegate: class {
    func numberOfItems(_ bar: ZXSegmentBar) -> Int
    func segmentBar(_ bar: ZXSegmentBar, itemForIndex index: Int) -> ZXSegmentBarItem
    func segmentBar(_ bar: ZXSegmentBar, didClickItemAtIndex index: Int)
    // 是否允许点击
    func segmentBar(_ bar: ZXSegmentBar, shouldClickItemAtIndex index: Int) -> Bool
}

extension ZXSegmentBarDelegate {
    func segmentBar(_ bar: ZXSegmentBar, didClickItemAtIndex index: Int) {}
}

public protocol ZXSegmentBarItem: class {
    var view: UIView { get }
    var idx: Int { get set }
    var isSelected: Bool { get set }
    func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event)
}

extension UIControl: ZXSegmentBarItem {
    public var view: UIView {
        return self
    }
    
    public var idx: Int {
        get {
            return tag
        } set {
            tag = newValue
        }
    }
}

public enum ZXSegmentIndicatorMode {
    case fix(CGSize)                    //固定indicator的size，(固定的size)
    case relative(CGFloat, CGFloat)     //相对当前选中的itemView的size进行适配，（width delta，height）
}

open class ZXSegmentBar: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubViews()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupSubViews()
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        setupSubViews()
    }
    
    private func setupSubViews() {
        addSubview(contentView)
        contentView.addSubview(stackView)
        contentView.addSubview(indicatorView)
        contentView.addSubview(bottomLineView)
        
        contentView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        stackView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        indicatorView.snp.makeConstraints { (make) in
            make.centerX.bottom.equalToSuperview()
            make.size.equalTo(CGSize.zero)
        }
        bottomLineView.snp.makeConstraints { (make) in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(bottomLineHeight)
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        guard isLoaded == false else { return }
        isLoaded = true
        reload()
    }
    
    //MARK: public
    public func itemAtIndex(_ index: Int) -> ZXSegmentBarItem? {
        guard index >= 0 && index < itemCache.count else { return nil }
        return itemCache[index]
    }
    
    public func selectItem(at index: Int, animated: Bool) {
        guard index != currentIndex else { return }
        
        if isLoaded {
            switchToIndex(index, from: currentIndex, animated: animated)
        } else {
            currentIndex = max(0, index)
        }
    }
    
    public func reload() {
        guard isLoaded, let del = delegate else { return }
        
        totalCount = del.numberOfItems(self)
        itemCache.removeAll()
        stackView.subviews.forEach { $0.removeFromSuperview() }
        setupContentView()
        switchToIndex(currentIndex, from: nil, animated: false)
    }
    
    //MARK: actions
    @objc private func itemViewClicked(_ sender: Any) {
        guard let item = sender as? ZXSegmentBarItem else { return }
        
        let index = item.idx
         
        if let delegate = delegate  {
            guard delegate.segmentBar(self, shouldClickItemAtIndex: index) else { return }
        } else {
            guard index != currentIndex, index < itemCache.count && index >= 0 else { return }
        }
        
        switchToIndex(index, from: currentIndex, animated: enableClickAnimation)
        delegate?.segmentBar(self, didClickItemAtIndex: index)
    }
    
    open func switchToIndex(_ index: Int, from fromIndex: Int?, animated: Bool) {
        guard index < itemCache.count && index >= 0 else { return }
        
        itemCache[index].isSelected = true
        if let preIndex = fromIndex, preIndex < itemCache.count {
            itemCache[preIndex].isSelected = false
        }
        
        currentIndex = index
        
        switchContentViewToIndex(index, animated: animated)
        switchIndicatorToIndex(index, animated: animated)
    }
    
    //MARK: public properties
    public weak var delegate: ZXSegmentBarDelegate?
    
    public var indicatorMode: ZXSegmentIndicatorMode = .relative(0, 2)
    
    public var itemPadding: CGFloat = 0 {
        didSet {
            stackView.spacing = itemPadding
        }
    }
    
    public var edgesInset: UIEdgeInsets = .zero
    
    public var bottomLineHeight: CGFloat = 1.0 {
        didSet {
            bottomLineView.snp.updateConstraints { (make) in
                make.height.equalTo(bottomLineHeight)
            }
        }
    }
    
    public var enableClickAnimation: Bool = true //点击切换时，是否显示动画
    
    
    public lazy var indicatorView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.orange
        return v
    }()
    
    public lazy var bottomLineView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.clear
        return v
    }()
    
    open var selectedIndex: Int { return currentIndex }
    
    //是否支持UIViewController的popGesture
    public var recogizePopGesture: Bool = true {
        didSet {
            self.contentView.enablePopGesture = recogizePopGesture
        }
    }
    
    //MARK: properties
    private var isLoaded = false
    private var totalCount = 0
    private var currentIndex = 0
    
    private(set) public var itemCache = [ZXSegmentBarItem]()
    
    private var indicatorCenterX: NSLayoutConstraint?
    private var indicatorWidth: NSLayoutConstraint?
    private var indicatorHeight: NSLayoutConstraint?
    
    private var indicatorCenterXConstraint: Constraint?
    
    public lazy var contentView: ZXSegmentScrollView = {
        let scrollView = ZXSegmentScrollView()
        scrollView.bounces = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.scrollsToTop = false
        return scrollView
    }()
    
    private lazy var stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.distribution = .fill
        return view
    }()
}

//MARK: switch
extension ZXSegmentBar {
    
    private func switchContentViewToIndex(_ index: Int, animated: Bool) {
        
        let itemFrame = itemCache[index].view.frame
        let maxOffsetX = contentView.contentSize.width - contentView.frame.width
        //使用当前选中item，刚好处于视图正中间的offsetX
        let expectOffsetX = itemFrame.origin.x - 0.5*(contentView.bounds.width - itemFrame.width)
        
        let offsetX = max(0, min(maxOffsetX, expectOffsetX))
        
        if animated {
            
            UIView.animate(withDuration: 0.25, animations: {
                self.contentView.contentOffset = CGPoint(x: offsetX, y: 0)
            })
            
        } else {
            
            self.contentView.contentOffset = CGPoint(x: offsetX, y: 0)
        }
    }
    
    private func switchIndicatorToIndex(_ index: Int, animated: Bool) {
        
        let targetView = itemCache[index].view
        
        func updateIndicatorViewConstraints() {
            indicatorView.snp.remakeConstraints { (make) in
                self.indicatorCenterXConstraint = make.centerX.equalTo(targetView).constraint
                make.bottom.equalToSuperview()
                switch indicatorMode {
                case .fix(let size):
                    make.size.equalTo(size)
                case .relative(let delta, let height):
                    make.width.equalTo(targetView).offset(-delta)
                    make.height.equalTo(height)
                }
            }
            indicatorView.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(withDuration: 0.25, animations: {
                updateIndicatorViewConstraints()
            })
        } else {
            updateIndicatorViewConstraints()
        }
    }
    
}

//MARK: indicator pos
extension ZXSegmentBar {
    
    internal func updateIndicatorPosition(_ distance: CGFloat, _ scrollWidth: CGFloat) {
        
        let change = distance / scrollWidth * 50
        indicatorCenterXConstraint?.update(offset: change)
    }
}

//MARK: layout
extension ZXSegmentBar {
    
    private func setupContentView() {
        guard let delegate = delegate else { return }
        
        for index in 0..<totalCount {
            let item = delegate.segmentBar(self, itemForIndex: index)
            item.idx = index
            item.addTarget(self, action: #selector(itemViewClicked(_:)), for: .touchUpInside)
            itemCache.append(item)
            stackView.addArrangedSubview(item.view)
        }
        
    }
    
}

