package openfl._internal.renderer.opengl.utils;

import lime.graphics.GLRenderContext;
import openfl._internal.renderer.opengl.GLRenderer;
import openfl._internal.renderer.opengl.utils.GraphicsRenderer;
import openfl._internal.renderer.opengl.utils.GraphicsRenderer.GLStack;
import openfl.display.Graphics;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.CapsStyle;
import openfl.display.DisplayObject;
import openfl.display.Graphics;
import openfl.display.JointStyle;
import openfl.display.LineScaleMode;
import openfl.display.TriangleCulling;
import openfl.geom.Matrix;
import openfl.geom.Point;

class DrawPath {
	
	public static var DEFAULT_LINE_STYLE:LineStyle = {
		
		width: 0,
		color: 0,
		alpha: 1,
		scaleMode: LineScaleMode.NORMAL,
		caps: CapsStyle.ROUND,
		joints: JointStyle.ROUND,
		miterLimit: 3
		
	}
	

	public var line:LineStyle;
	public var fill:FillType;
	public var fillIndex:Int = 0;

	public var points:Array<Float> = [];

	public var type:GraphicType = Polygon;

	public function new() {
		line = Reflect.copy(DEFAULT_LINE_STYLE);
		fill = None;
	}

	public function update(line:LineStyle, fill:FillType, fillIndex:Int):Void {
		updateLine(line);
		this.fill = fill;
		this.fillIndex = fillIndex;
	}

	public function updateLine(line:LineStyle):Void {
		this.line.width = line.width;
		this.line.color = line.color;
		this.line.alpha = line.alpha == null ? 1 : line.alpha;
		this.line.scaleMode = line.scaleMode == null ? LineScaleMode.NORMAL : line.scaleMode;
		this.line.caps = line.caps == null ? CapsStyle.ROUND : line.caps;
		this.line.joints = line.joints == null ? JointStyle.ROUND : line.joints;
		this.line.miterLimit = line.miterLimit;
	}
	
	public static function getStack(graphics:Graphics, gl:GLRenderContext):GLStack {
		return PathBuiler.build(graphics, gl);
	}
	
}

@:access(openfl._internal.renderer.opengl.utils.GraphicsRenderer)
@:access(openfl.display.Graphics)
class PathBuiler {
	
	private static var __currentPath:DrawPath;
	private static var __drawPaths:Array<DrawPath>;
	private static var __line:LineStyle;
	private static var __fill:FillType;
	private static var __fillIndex:Int = 0;
	
	private static function closePath():Void {
		var l = __currentPath.points.length;
		if (l <= 0) return;
		// the paths are only closed when the type is a polygon and there is a fill
		if (__currentPath.type == Polygon && __currentPath.fill != None) {
			var sx = __currentPath.points[0];
			var sy = __currentPath.points[1];
			var ex = __currentPath.points[l - 2];
			var ey = __currentPath.points[l - 1];
			
			if (!(sx == ex && sy == ey)) {
				__currentPath.points.push (sx);
				__currentPath.points.push (sy);
			}
		}
	}
	
	private static function endFill ():Void {
		
		__fill = None;
		__fillIndex++;
		
	}
	
	private static function moveTo (x:Float, y:Float):Void {
		
		graphicDataPop ();
		__currentPath = new DrawPath ();
		__currentPath.update(__line, __fill, __fillIndex);
		__currentPath.type = Polygon;
		__currentPath.points.push (x);
		__currentPath.points.push (y);
		
		__drawPaths.push (__currentPath);
		
	}
	
	private inline static function graphicDataPop ():Void {
		
		if (__currentPath.points.length == 0) {
			__drawPaths.pop ();
		} else {
			closePath();
		}
		
	}
	
	public static function build(graphics:Graphics, gl:GLRenderContext):GLStack {
		
		var glStack:GLStack = null;
		var bounds = graphics.__bounds;
		
		__drawPaths = new Array ();
		__currentPath = new DrawPath ();
		__line = Reflect.copy (DrawPath.DEFAULT_LINE_STYLE);
		__fill = None;
		__fillIndex = 0;
		
		if (!graphics.__visible || graphics.__commands.length == 0 || bounds == null || bounds.width == 0 || bounds.height == 0) {
			
			glStack = graphics.__glStack[GLRenderer.glContextId] = new GLStack (gl);
			
		} else {
			
			glStack = graphics.__glStack[GLRenderer.glContextId];
			
			if (glStack == null) {
				
				glStack = graphics.__glStack[GLRenderer.glContextId] = new GLStack (gl);
				
			}
			
			for (command in graphics.__commands) {
				
				switch (command) {
					
					case BeginBitmapFill (bitmap, matrix, repeat, smooth):
						
						endFill();
						__fill = bitmap != null ? Texture(new Bitmap(bitmap), matrix, repeat, smooth) : None;
						
						if (__currentPath.points.length == 0) {
							graphicDataPop();
							__currentPath = new DrawPath();
							__currentPath.update(__line, __fill, __fillIndex);
							__currentPath.points = [];
							__currentPath.type = Polygon;
							__drawPaths.push(__currentPath);
						}
					
					case BeginFill (rgb, alpha):
						
						endFill();
						__fill = alpha > 0 ? Color(rgb & 0xFFFFFF, alpha) : None;

						if (__currentPath.points.length == 0) {
							graphicDataPop();
							__currentPath = new DrawPath();
							__currentPath.update(__line, __fill, __fillIndex);
							__currentPath.points = [];
							__currentPath.type = Polygon;
							__drawPaths.push(__currentPath);
						}
					
					case CubicCurveTo (cx, cy, cx2, cy2, x, y):
						
						if (__currentPath.points.length == 0) {
							
							moveTo (0, 0);
							
						}
						
						var n = 20;
						var dt:Float = 0;
						var dt2:Float = 0;
						var dt3:Float = 0;
						var t2:Float = 0;
						var t3:Float = 0;
						
						var points = __currentPath.points;
						var fromX = points[points.length-2];
						var fromY = points[points.length-1];
						
						var px:Float = 0;
						var py:Float = 0;
						
						var tmp:Float = 0;
						
						for (i in 1...(n + 1)) {
							
							tmp = i / n;
							
							dt = 1 - tmp;
							dt2 = dt * dt;
							dt3 = dt2 * dt;
							
							t2 = tmp * tmp;
							t3 = t2 * tmp;
							
							px = dt3 * fromX + 3 * dt2 * tmp * cx + 3 * dt * t2 * cx2 + t3 * x;
							py = dt3 * fromY + 3 * dt2 * tmp * cy + 3 * dt * t2 * cy2 + t3 * y;
							
							points.push (px);
							points.push (py);
							
						}
					
					case CurveTo (cx, cy, x, y):
						
						if (__currentPath.points.length == 0) {
							
							moveTo (0, 0);
							
						}
						
						var xa:Float = 0;
						var ya:Float = 0;
						var n = 20;
						
						var points = __currentPath.points;
						var fromX = points[points.length-2];
						var fromY = points[points.length-1];
						
						var px:Float = 0;
						var py:Float = 0;
						
						var tmp:Float = 0;
						
						for (i in 1...(n + 1)) {
							
							tmp = i / n;
							
							xa = fromX + ((cx - fromX) * tmp);
							ya = fromY + ((cy - fromY) * tmp);
							
							px = xa + (((cx + (x - cx) * tmp)) - xa) * tmp;
							py = ya + (((cy + (y - cy) * tmp)) - ya) * tmp;
							
							points.push (px);
							points.push (py);
							
						}
					
					case DrawCircle (x, y, radius):
						
						graphicDataPop ();
						
						__currentPath = new DrawPath ();
						__currentPath.update(__line, __fill, __fillIndex);
						__currentPath.type = Circle;
						__currentPath.points = [ x, y, radius ];
						
						__drawPaths.push (__currentPath);
					
					case DrawEllipse (x, y, width, height):
						
						graphicDataPop ();
						
						__currentPath = new DrawPath ();
						__currentPath.update(__line, __fill, __fillIndex);
						__currentPath.type = Ellipse;
						__currentPath.points = [ x, y, width, height ];
						
						__drawPaths.push (__currentPath);
					
					case DrawRect (x, y, width, height):
						
						graphicDataPop();
						
						__currentPath = new DrawPath ();
						__currentPath.update(__line, __fill, __fillIndex);
						__currentPath.type = Rectangle (false);
						__currentPath.points = [ x, y, width, height ];
						
						__drawPaths.push (__currentPath);
					
					case DrawRoundRect (x, y, width, height, rx, ry):
						
						graphicDataPop ();
						
						__currentPath = new DrawPath ();
						__currentPath.update(__line, __fill, __fillIndex);
						__currentPath.type = Rectangle (true);
						__currentPath.points = [ x, y, width, height, rx, ry != -1 ? ry : rx ];
						
						__drawPaths.push (__currentPath);
					
					case EndFill:
						
						endFill ();
					
					case LineStyle (thickness, color, alpha, pixelHinting, scaleMode, caps, joints, miterLimit):
						
						__line = Reflect.copy (DrawPath.DEFAULT_LINE_STYLE);
						
						if (thickness == null || thickness == Math.NaN || thickness < 0) {
							
							__line.width = 0;
							
						} else if (thickness == 0) {
							
							__line.width = 1;
							
						} else {
							
							__line.width = thickness;
							
						}
						
						graphicDataPop ();
						
						__line.color = color;
						__line.alpha = alpha;
						__line.scaleMode = scaleMode;
						__line.caps = caps;
						__line.joints = joints;
						__line.miterLimit = miterLimit;
						
						__currentPath = new DrawPath ();
						__currentPath.update(__line, __fill, __fillIndex);
						__currentPath.points = [];
						__currentPath.type = GraphicType.Polygon;
						
						__drawPaths.push (__currentPath);
					
					case LineTo (x, y):
						
						__currentPath.points.push (x);
						__currentPath.points.push (y);
					
					case MoveTo (x, y):
						
						moveTo(x, y);
						
					case DrawTriangles (vertices, indices, uvtData, culling, colors, blendMode):
						
						graphicDataPop ();
						
						__currentPath = new DrawPath ();
						__currentPath.update (__line, __fill, __fillIndex);
						if (vertices == null) {
							break;
						}
						if (indices == null) {
							indices = new Vector<Int>();
						}
						if (uvtData == null) {
							uvtData = new Vector<Float>();
						}
						if (culling == null) {
							culling = NONE;
						}
						if (colors == null) {
							colors = new Vector<Int>();
						}
						__currentPath.type = GraphicType.DrawTriangles (vertices, indices, uvtData, culling, colors, blendMode);

						__drawPaths.push (__currentPath);
					
					default:
						
				}
				
			}
			
			closePath();
			
		}
		
		graphics.__drawPaths = __drawPaths;
		
		return glStack;
	}
}

typedef LineStyle = {
	
	width:Float,
	color:Int,
	alpha:Null<Float>,
	
	scaleMode:LineScaleMode,
	caps:CapsStyle,
	joints:JointStyle,
	miterLimit:Float
	
}


enum FillType {
	None;
	Color(color:Int, alpha:Float);
	Texture(bitmap:Bitmap, matrix:Matrix, repeat:Bool, smooth:Bool);
	Gradient;
}