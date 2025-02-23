import SwiftUI
import UIKit

struct InfiniteScrollHelper: UIViewRepresentable {
    @Binding var contentSize: CGSize
    @Binding var offset: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(contentSize: contentSize, offset: $offset)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        
        DispatchQueue.main.async {
            if let scrollView = view.scrollView as? UIScrollView {
                context.coordinator.defaultDelegate = scrollView.delegate
                scrollView.delegate = context.coordinator
                scrollView.decelerationRate = .normal
                scrollView.showsHorizontalScrollIndicator = false
                scrollView.contentInsetAdjustmentBehavior = .never
                scrollView.isPagingEnabled = false
                scrollView.bounces = true
                scrollView.clipsToBounds = false
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        context.coordinator.contentSize = contentSize
        
        if let scrollView = uiView.scrollView as? UIScrollView {
            if context.coordinator.isAdjusting { return }
            
            let currentOffset = scrollView.contentOffset.x
            if abs(currentOffset - offset) > 1 {
                context.coordinator.isAdjusting = true
                scrollView.setContentOffset(CGPoint(x: offset, y: 0), animated: false)
                context.coordinator.isAdjusting = false
            }
        }
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var contentSize: CGSize
        var isAdjusting = false
        @Binding var offset: CGFloat
        weak var defaultDelegate: UIScrollViewDelegate?
        
        init(contentSize: CGSize, offset: Binding<CGFloat>) {
            self.contentSize = contentSize
            self._offset = offset
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isAdjusting else { return }
            
            let offsetX = scrollView.contentOffset.x
            offset = offsetX
            
            defaultDelegate?.scrollViewDidScroll?(scrollView)
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            defaultDelegate?.scrollViewWillBeginDragging?(scrollView)
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            defaultDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            defaultDelegate?.scrollViewDidEndDecelerating?(scrollView)
        }
    }
}

extension UIView {
    var scrollView: UIScrollView? {
        if let superview = self.superview as? UIScrollView {
            return superview
        }
        return superview?.scrollView
    }
}
