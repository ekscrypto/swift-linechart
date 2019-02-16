


import UIKit
import QuartzCore

// delegate method
public protocol LineChartDelegate {
    func didSelectDataPoint(_ x: CGFloat, yValues: [CGFloat])
}

/**
 * LineChart
 */
open class LineChart: UIView {
    
    /**
    * Helpers class
    */
    fileprivate class Helpers {
        
        /**
        * Convert hex color to UIColor
        */
        fileprivate class func UIColorFromHex(_ hex: Int) -> UIColor {
            let red = CGFloat((hex & 0xFF0000) >> 16) / 255.0
            let green = CGFloat((hex & 0xFF00) >> 8) / 255.0
            let blue = CGFloat((hex & 0xFF)) / 255.0
            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        }
        
        /**
        * Lighten color.
        */
        fileprivate class func lightenUIColor(_ color: UIColor) -> UIColor {
            var h: CGFloat = 0
            var s: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return UIColor(hue: h, saturation: s, brightness: b * 1.5, alpha: a)
        }
    }
    
    public struct Labels {
        public var visible: Bool = true
        public var values: [String] = []
    }
    
    public struct Grid {
        public var visible: Bool = true
        public var count: CGFloat = 10
        // #eeeeee
        public var color: UIColor = UIColor(red: 238/255.0, green: 238/255.0, blue: 238/255.0, alpha: 1)
    }
    
    public struct Axis {
        public var visible: Bool = true
        // #607d8b
        public var color: UIColor = UIColor(red: 96/255.0, green: 125/255.0, blue: 139/255.0, alpha: 1)
        public var inset: CGFloat = 15
    }
    
    public struct Coordinate {
        // public
        public var labels: Labels = Labels()
        public var grid: Grid = Grid()
        public var axis: Axis = Axis()
        
        // private
        fileprivate var linear: LinearScale?
        fileprivate var scale: ((CGFloat) -> CGFloat)?
        fileprivate var invert: ((CGFloat) -> CGFloat)?
        fileprivate var ticks: (CGFloat, CGFloat, CGFloat)?
    }
    
    public struct Animation {
        public var enabled: Bool = true
        public var duration: CFTimeInterval = 1
    }
    
    public struct Dots {
        public var visible: Bool = true
        public var color: UIColor = UIColor.white
        public var innerRadius: CGFloat = 8
        public var outerRadius: CGFloat = 12
        public var innerRadiusHighlighted: CGFloat = 8
        public var outerRadiusHighlighted: CGFloat = 12
    }
    
    // default configuration
    open var area: Bool = true
    open var animation: Animation = Animation()
    open var dots: Dots = Dots()
    open var lineWidth: CGFloat = 2
    
    open var x: Coordinate = Coordinate()
    open var y: Coordinate = Coordinate()

    
    // values calculated on init
    fileprivate var drawingHeight: CGFloat = 0 {
        didSet {
            let max = getMaximumValue()
            let min = getMinimumValue()
            let linear = LinearScale(domain: [min, max], range: [0, drawingHeight])
            y.linear = linear
            y.scale = linear.scale()
            y.ticks = linear.ticks(Int(y.grid.count))
        }
    }
    fileprivate var drawingWidth: CGFloat = 0 {
        didSet {
            let data = dataStore[0]
            let xAxisCap = data.count > 1 ? CGFloat(data.count - 1) : 1.0
            let linear = LinearScale(domain: [0.0, xAxisCap], range: [0, drawingWidth])
            x.linear = linear
            x.scale = linear.scale()
            x.invert = linear.invert()
            x.ticks = linear.ticks(Int(x.grid.count))
        }
    }
    
    open var delegate: LineChartDelegate?
    
    // data stores
    fileprivate var dataStore: [[CGFloat]] = []
    fileprivate var dotsDataStore: [[DotCALayer]] = []
    fileprivate var lineLayerStore: [CAShapeLayer] = []
    
    fileprivate var removeAll: Bool = false
    
    // category10 colors from d3 - https://github.com/mbostock/d3/wiki/Ordinal-Scales
    open var colors: [UIColor] = [
        UIColor(red: 0.121569, green: 0.466667, blue: 0.705882, alpha: 1),
        UIColor(red: 1, green: 0.498039, blue: 0.054902, alpha: 1),
        UIColor(red: 0.172549, green: 0.627451, blue: 0.172549, alpha: 1),
        UIColor(red: 0.839216, green: 0.152941, blue: 0.156863, alpha: 1),
        UIColor(red: 0.580392, green: 0.403922, blue: 0.741176, alpha: 1),
        UIColor(red: 0.54902, green: 0.337255, blue: 0.294118, alpha: 1),
        UIColor(red: 0.890196, green: 0.466667, blue: 0.760784, alpha: 1),
        UIColor(red: 0.498039, green: 0.498039, blue: 0.498039, alpha: 1),
        UIColor(red: 0.737255, green: 0.741176, blue: 0.133333, alpha: 1),
        UIColor(red: 0.0901961, green: 0.745098, blue: 0.811765, alpha: 1)
    ]
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
    }

    convenience init() {
        self.init(frame: CGRect.zero)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override open func draw(_ rect: CGRect) {
        
        if removeAll {
            let context = UIGraphicsGetCurrentContext()
            context?.clear(rect)
            return
        }
        
        self.drawingHeight = self.bounds.height - y.axis.inset
        self.drawingWidth = self.bounds.width - x.axis.inset
        
        // remove all labels
        for view: AnyObject in self.subviews {
            view.removeFromSuperview()
        }
        
        // remove all lines on device rotation
        for lineLayer in lineLayerStore {
            lineLayer.removeFromSuperlayer()
        }
        lineLayerStore.removeAll()
        
        // remove all dots on device rotation
        for dotsData in dotsDataStore {
            for dot in dotsData {
                dot.removeFromSuperlayer()
            }
        }
        dotsDataStore.removeAll()
        
        // draw grid
        if x.grid.visible { drawXGrid() }
        if y.grid.visible { drawYGrid() }
        
        // draw axes
        if x.axis.visible && y.axis.visible { drawAxes() }
        
        // draw labels
        if x.labels.visible { drawXLabels() }
        if y.labels.visible { drawYLabels() }
        
        // draw lines
        for (lineIndex, _) in dataStore.enumerated() {
            
            drawLine(lineIndex)
            
            // draw dots
            if dots.visible { drawDataDots(lineIndex) }
            
            // draw area under line chart
            if area { drawAreaBeneathLineChart(lineIndex) }
            
        }
        
    }
    
    
    
    /**
     * Get y value for given x value. Or return zero or maximum value.
     */
    fileprivate func getYValuesForXValue(_ x: Int) -> [CGFloat] {
        var result: [CGFloat] = []
        for lineData in dataStore {
            if x < 0 {
                result.append(lineData[0])
            } else if x > lineData.count - 1 {
                result.append(lineData[lineData.count - 1])
            } else {
                result.append(lineData[x])
            }
        }
        return result
    }
    
    
    
    /**
     * Handle touch events.
     */
    fileprivate func handleTouchEvents(_ touches: Set<UITouch>, event: UIEvent?) {
        if (self.dataStore.isEmpty) {
            return
        }
        guard let point = touches.first else { return }
        let xValue = point.location(in: self).x
        if let invertFunction = self.x.invert {
            let inverted = invertFunction(xValue - x.axis.inset)
            let rounded = Int(round(Double(inverted)))
            let yValues: [CGFloat] = getYValuesForXValue(rounded)
            highlightDataPoints(rounded)
            delegate?.didSelectDataPoint(CGFloat(rounded), yValues: yValues)
        }
    }
    
    /**
     * Listen on touch end event.
     */
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchEvents(touches, event: event)
    }

    /**
     * Listen on touch move event
     */
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchEvents(touches, event: event)
    }
    
    /**
     * Highlight data points at index.
     */
    fileprivate func highlightDataPoints(_ index: Int) {
        for (lineIndex, dotsData) in dotsDataStore.enumerated() {
            // make all dots white again
            for dot in dotsData {
                dot.backgroundColor = dots.color.cgColor
            }
            // highlight current data point
            var dot: DotCALayer
            if index < 0 {
                dot = dotsData[0]
            } else if index > dotsData.count - 1 {
                dot = dotsData[dotsData.count - 1]
            } else {
                dot = dotsData[index]
            }
            dot.backgroundColor = Helpers.lightenUIColor(colors[lineIndex]).cgColor
        }
    }
    
    
    
    /**
     * Draw small dot at every data point.
     */
    fileprivate func drawDataDots(_ lineIndex: Int) {
        var dotLayers: [DotCALayer] = []
        var data = self.dataStore[lineIndex]
        guard
            let scaleYFunction = self.y.scale,
            let scaleXFunction = self.x.scale
            else { return }

        for index in 0..<data.count {
            let xValue = scaleXFunction(CGFloat(index)) + x.axis.inset - dots.outerRadius/2
            let yValue = self.bounds.height - scaleYFunction(data[index]) - y.axis.inset - dots.outerRadius/2
            
            // draw custom layer with another layer in the center
            let dotLayer = DotCALayer()
            dotLayer.dotInnerColor = colors[lineIndex]
            dotLayer.innerRadius = dots.innerRadius
            dotLayer.backgroundColor = dots.color.cgColor
            dotLayer.cornerRadius = dots.outerRadius / 2
            dotLayer.frame = CGRect(x: xValue, y: yValue, width: dots.outerRadius, height: dots.outerRadius)
            self.layer.addSublayer(dotLayer)
            dotLayers.append(dotLayer)
            
            // animate opacity
            if animation.enabled {
                let anim = CABasicAnimation(keyPath: "opacity")
                anim.duration = animation.duration
                anim.fromValue = 0
                anim.toValue = 1
                dotLayer.add(anim, forKey: "opacity")
            }
            
        }
        dotsDataStore.append(dotLayers)
    }
    
    
    
    /**
     * Draw x and y axis.
     */
    fileprivate func drawAxes() {
        guard let scaleYFunction = self.y.scale else { return }
        let height = self.bounds.height
        let width = self.bounds.width
        let path = UIBezierPath()
        // draw x-axis
        x.axis.color.setStroke()
        let y0 = height - scaleYFunction(0) - y.axis.inset
        path.move(to: CGPoint(x: x.axis.inset, y: y0))
        path.addLine(to: CGPoint(x: width, y: y0))
        path.stroke()
        // draw y-axis
        y.axis.color.setStroke()
        path.move(to: CGPoint(x: x.axis.inset, y: height - y.axis.inset))
        path.addLine(to: CGPoint(x: x.axis.inset, y: 0))
        path.stroke()
    }
    
    
    
    /**
     * Get maximum value in all arrays in data store.
     */
    fileprivate func getMaximumValue() -> CGFloat {
        var max: CGFloat = dataStore.first?.first ?? 1
        for data in dataStore {
            max = CGFloat.maximum(max, data.max() ?? 1.0)
        }
        return max
    }
    
    
    
    /**
     * Get maximum value in all arrays in data store.
     */
    fileprivate func getMinimumValue() -> CGFloat {
        var min: CGFloat = dataStore.first?.first ?? 0
        for data in dataStore {
            min = CGFloat.minimum(min, data.min() ?? 0.0)
        }
        return min
    }
    
    
    
    /**
     * Draw line.
     */
    fileprivate func drawLine(_ lineIndex: Int) {
        guard
            let scaleYFunction = self.y.scale,
            let scaleXFunction = self.x.scale,
            self.dataStore.count > lineIndex,
            self.dataStore[lineIndex].count > 0
            else { return }

        var data = self.dataStore[lineIndex]
        let path = UIBezierPath()
        
        var xValue = scaleXFunction(0) + x.axis.inset
        var yValue = self.bounds.height - scaleYFunction(data[0]) - y.axis.inset
        path.move(to: CGPoint(x: xValue, y: yValue))
        for index in 1..<data.count {
            xValue = scaleXFunction(CGFloat(index)) + x.axis.inset
            yValue = self.bounds.height - scaleYFunction(data[index]) - y.axis.inset
            path.addLine(to: CGPoint(x: xValue, y: yValue))
        }
        
        let layer = CAShapeLayer()
        layer.frame = self.bounds
        layer.path = path.cgPath
        layer.strokeColor = colors[lineIndex].cgColor
        layer.fillColor = nil
        layer.lineWidth = lineWidth
        self.layer.addSublayer(layer)
        
        // animate line drawing
        if animation.enabled {
            let anim = CABasicAnimation(keyPath: "strokeEnd")
            anim.duration = animation.duration
            anim.fromValue = 0
            anim.toValue = 1
            layer.add(anim, forKey: "strokeEnd")
        }
        
        // add line layer to store
        lineLayerStore.append(layer)
    }
    
    
    
    /**
     * Fill area between line chart and x-axis.
     */
    fileprivate func drawAreaBeneathLineChart(_ lineIndex: Int) {
        guard
            let scaleYFunction = self.y.scale,
            let scaleXFunction = self.x.scale
            else { return }

        var data = self.dataStore[lineIndex]
        let path = UIBezierPath()
        
        colors[lineIndex].withAlphaComponent(0.2).setFill()
        // move to origin
        path.move(to: CGPoint(x: x.axis.inset, y: self.bounds.height - scaleYFunction(0) - y.axis.inset))
        // draw whole line chart
        for index in 0..<data.count {
            let x1 = scaleXFunction(CGFloat(index)) + x.axis.inset
            let y1 = self.bounds.height - scaleYFunction(data[index]) - y.axis.inset
            path.addLine(to: CGPoint(x: x1, y: y1))
        }
        // move down to x axis
        path.addLine(to: CGPoint(x: scaleXFunction(CGFloat(data.count - 1)) + x.axis.inset, y: self.bounds.height - scaleYFunction(0) - y.axis.inset))
        // move to origin
        path.addLine(to: CGPoint(x: x.axis.inset, y: self.bounds.height - scaleYFunction(0) - y.axis.inset))
        path.fill()
    }
    
    
    
    /**
     * Draw x grid.
     */
    fileprivate func drawXGrid() {
        guard
            let xTicks = self.x.ticks,
            let scaleXFunction = self.x.scale
            else { return }
        x.grid.color.setStroke()
        let path = UIBezierPath()
        var x1: CGFloat
        let y1: CGFloat = self.bounds.height - y.axis.inset
        let y2: CGFloat = 0
        let (start, stop, step) = xTicks
//        print("Will be drawing grid from \(start) to \(stop) by \(step), bounds: \(self.bounds)")
        for i in stride(from: start, through: stop, by: step){
            x1 = scaleXFunction(i) + x.axis.inset
            path.move(to: CGPoint(x: x1, y: y1))
            path.addLine(to: CGPoint(x: x1, y: y2))
        }
        path.stroke()
    }

    /**
     * Draw y grid.
     */
    fileprivate func drawYGrid() {
        guard
            let yTicks = self.y.ticks,
            let scaleYFunction = self.y.scale
            else { return }
        self.y.grid.color.setStroke()
        let path = UIBezierPath()
        let x1: CGFloat = x.axis.inset
        let x2: CGFloat = self.bounds.width
        var y1: CGFloat
        let (start, stop, step) = yTicks
        for i in stride(from: start, through: stop, by: step){
            y1 = self.bounds.height - scaleYFunction(i) - y.axis.inset
            path.move(to: CGPoint(x: x1, y: y1))
            path.addLine(to: CGPoint(x: x2, y: y1))
        }
        path.stroke()
    }

    /**
     * Draw x labels.
     */
    fileprivate func drawXLabels() {
        guard
            let xLinear = self.x.linear,
            let scaleXFunction = self.x.scale
            else { return }
        let xAxisData = self.dataStore[0]
        let y = self.bounds.height - self.y.axis.inset
        let (_, _, step) = xLinear.ticks(xAxisData.count)
        let width = scaleXFunction(step)
        let font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption2)
        let labelHeight = font.pointSize * 1.5
        if self.y.axis.inset < labelHeight {
            print("Warning: X-axis labels may be cut-off and/or bleed outside rendering view")
        }
        var text: String
        for (index, _) in xAxisData.enumerated() {
            let xValue = scaleXFunction(CGFloat(index)) + x.axis.inset - (width / 2)
            let label = UILabel(frame: CGRect(x: xValue, y: y, width: width, height: labelHeight))
            label.font = font
            label.textAlignment = .center
            if (x.labels.values.count != 0) {
                text = x.labels.values[index]
            } else {
                text = String(index)
            }
            label.text = text
            self.addSubview(label)
        }
    }
    
    
    
    /**
     * Draw y labels.
     */
    fileprivate func drawYLabels() {
        guard
            let yTicks = self.y.ticks,
            let scaleYFunction = self.y.scale,
            var precision = self.y.linear?.precision(Int(self.y.grid.count))
            else { return }
        var decimals = 0
        while precision < 1.0 {
            decimals += 1
            precision *= 10
        }
        let format = "%.\(decimals)f"
        var yValue: CGFloat
        let font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption2)
        let labelHeight = font.pointSize * 1.5
        let offset = y.axis.inset + labelHeight * 0.5
        let (start, stop, step) = yTicks
        for i in stride(from: start, through: stop, by: step){
            yValue = self.bounds.height - scaleYFunction(i) - offset
            guard yValue > 0 else { return }
            let label = UILabel(frame: CGRect(x: 0, y: yValue, width: x.axis.inset, height: labelHeight))
            label.font = font
            label.textAlignment = .center
            label.text = String(format: format, i)
            self.addSubview(label)
        }
    }
    
    
    
    /**
     * Add line chart
     */
    open func addLine(_ data: [CGFloat]) {
        self.dataStore.append(data)
        self.setNeedsDisplay()
    }
    
    
    
    /**
     * Make whole thing white again.
     */
    open func clearAll() {
        self.removeAll = true
        clear()
        self.setNeedsDisplay()
        self.removeAll = false
    }
    
    
    
    /**
     * Remove charts, areas and labels but keep axis and grid.
     */
    open func clear() {
        // clear data
        dataStore.removeAll()
        self.setNeedsDisplay()
    }
}



/**
 * DotCALayer
 */
class DotCALayer: CALayer {
    
    var innerRadius: CGFloat = 8
    var dotInnerColor = UIColor.black
    
    override init() {
        super.init()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        let inset = self.bounds.size.width - innerRadius
        let innerDotLayer = CALayer()
        innerDotLayer.frame = self.bounds.insetBy(dx: inset/2, dy: inset/2)
        innerDotLayer.backgroundColor = dotInnerColor.cgColor
        innerDotLayer.cornerRadius = innerRadius / 2
        self.addSublayer(innerDotLayer)
    }
    
}



/**
 * LinearScale
 */
open class LinearScale {
    
    var domain: [CGFloat]
    var range: [CGFloat]
    
    public init(domain: [CGFloat] = [0, 1], range: [CGFloat] = [0, 1]) {
        self.domain = LinearScale.scaleExtent(domain)
        self.range = range
    }
    
    open func scale() -> (_ x: CGFloat) -> CGFloat {
        return bilinear(domain, range: range, uninterpolate: uninterpolate, interpolate: interpolate)
    }
    
    open func invert() -> (_ x: CGFloat) -> CGFloat {
        return bilinear(range, range: domain, uninterpolate: uninterpolate, interpolate: interpolate)
    }
    
    open func ticks(_ m: Int) -> (CGFloat, CGFloat, CGFloat) {
        return scale_linearTicks(domain, m: m)
    }
    
    open func precision(_ m: Int) -> CGFloat {
        let span = domain[1] - domain[0]
        let divisions = m > 0 ? m : 1
        let precision = CGFloat(pow(10, floor(log(Double(span) / Double(divisions)) / M_LN10)))
        return precision
    }
    
    fileprivate func scale_linearTicks(_ domain: [CGFloat], m: Int) -> (CGFloat, CGFloat, CGFloat) {
        let span = domain[1] - domain[0]
        let divisions = m > 0 ? m : 1
        let precision = CGFloat(pow(10, floor(log(Double(span) / Double(divisions)) / M_LN10)))
        
//        print("\(#function) domain: \(domain) m: \(m) precision: \(precision)")
        
        // Round start and stop values to step interval.
        let start = floor(domain[0] / precision) * precision
        let stop = ceil(domain[1] / precision) * precision
        let step = floor((stop - start) / CGFloat(divisions) / precision) * precision

//        print("\(#function) start: \(start) stop: \(stop) step: \(step)")

        return (start, stop, step)
    }
    
    fileprivate static func scaleExtent(_ domain: [CGFloat]) -> [CGFloat] {
        if let minimum = domain.min(), let maximum = domain.max() {
            if minimum < maximum {
                return [minimum, maximum]
            } else {
                if minimum > 0 {
                    return [0, minimum]
                }
                if minimum < 0 {
                    return [minimum, 0]
                }
            }
        }
        return [0, 1]
    }
    
    fileprivate func interpolate(_ a: CGFloat, b: CGFloat) -> (_ c: CGFloat) -> CGFloat {
        var diff = b - a
        func f(_ c: CGFloat) -> CGFloat {
            return (a + diff) * c
        }
        return f
    }
    
    fileprivate func uninterpolate(_ a: CGFloat, b: CGFloat) -> (_ c: CGFloat) -> CGFloat {
        var diff = b - a
        var re = diff != 0 ? 1 / diff : 0
        func f(_ c: CGFloat) -> CGFloat {
            return (c - a) * re
        }
        return f
    }
    
    fileprivate func bilinear(_ domain: [CGFloat], range: [CGFloat], uninterpolate: (_ a: CGFloat, _ b: CGFloat) -> (_ c: CGFloat) -> CGFloat, interpolate: (_ a: CGFloat, _ b: CGFloat) -> (_ c: CGFloat) -> CGFloat) -> (_ c: CGFloat) -> CGFloat {
        var u: (_ c: CGFloat) -> CGFloat = uninterpolate(domain[0], domain[1])
        var i: (_ c: CGFloat) -> CGFloat = interpolate(range[0], range[1])
        func f(_ d: CGFloat) -> CGFloat {
            return i(u(d))
        }
        return f
    }
    
}
