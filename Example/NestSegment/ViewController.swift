//
//  ViewController.swift
//  NestSegment
//
//  Created by Paul.Yin on 04/24/2021.
//  Copyright (c) 2021 Paul.Yin. All rights reserved.
//

import UIKit
import NestSegment

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        title = "NestSegment"
        
        view.addSubview(nestSegment)
        nestSegment.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        nestSegment.configHeader(listVC: EmojiExplorerViewController())
        nestSegment.reload()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    lazy var nestSegment: ZXNestSegmentContainer = {
        let container = ZXNestSegmentContainer(parentVC: self)
        container.segmentDelegate = self
        container.segmentDataSource = self
        container.bounces = false
        container.container.contentView.bounces = false
        container.alwaysBounceHorizontal = false
        return container
    }()
    
    var vc1 = EmojiExplorerViewController()
    
    var vc2 = EmojiExplorerViewController()
    
    lazy var items: [(String, EmojiExplorerViewController)] = [
        ("111111", vc1),
        ("222222", vc2)]
}

extension ViewController: ZXSegmentContainerDelegate, ZXSegmentContainerDataSource {
    func container(_ container: ZXSegmentContainer, contentItemFor index: Int) -> ZXSegmentContentItem {
        items[index].1
    }
    
    func container(_ container: ZXSegmentContainer, topBarItemFor index: Int) -> ZXSegmentBarItem {
        let title = items[index].0
        let barItem = ZXSegmentBar.defaultBarItem(title)
        return barItem
    }
    
    func numberOfItems(_ container: ZXSegmentContainer) -> Int {
        items.count
    }
    
}

extension ZXSegmentBar {
    
    public static func defaultBarItem(_ title: String, btnInsert: UIEdgeInsets = UIEdgeInsets(top: 10, left: 13.0, bottom: 10, right: 13.0)) -> ZXSegmentBarItem {
        let button = UIButton()
        
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.setTitle(title.trimmingCharacters(in: CharacterSet.whitespaces), for: .normal)
        button.setTitleColor(UIColor.darkGray, for: .normal)
        button.setTitleColor(UIColor.orange, for: .selected)
        
        /** 调节item的间距 */
        button.contentEdgeInsets = btnInsert
        
        return button
    }
}

extension EmojiExplorerViewController: ZXSegmentContentViewController, YFNestSegmentProtocol {
    @objc var scrollView: UIScrollView {
        return collectionView
    }
}
