//
//  GameScene.swift
//  SKTest
//
//  Created by Anthony DeSouza on 2017-04-11.
//  Copyright © 2017 Anthony DeSouza. All rights reserved.
//

import SpriteKit
import GameplayKit

extension CGSize {
    public init(rows: Int, cols: Int) {
        self = CGSize(width: rows, height: cols)
    }
    
    var rows: Int {
        return Int(self.width)
    }
    
    var cols: Int {
        return Int(self.height)
    }
}

// To see Swift classes from ObjC they MUST be prefaced with @objc and be public/open
@objc public class RogueScene: SKScene {
    fileprivate let grid: CGSize
    fileprivate let cellSize: CGSize
    fileprivate let initialSize: CGSize
    
    fileprivate var fgTextures = [SKTexture]()
    fileprivate var bgTextures = [SKTexture]()
    var cells = [[Cell]]()
    fileprivate var textureMap: [String : SKTexture] = [:]
    
    // We don't want small letters scaled to huge proportions, so we only allow letters to stretch 
    // within a certain range (e.g. size of M +/- 20%)
    fileprivate lazy var maxScaleFactor: CGFloat = {
        let char: NSString = "M" // Good letter to do the base calculations from
        let calcBounds: CGRect = char.boundingRect(with: CGSize(width: 0, height: 0),
                                                   options: [.usesDeviceMetrics, .usesFontLeading],
                                                   attributes: [NSFontAttributeName: UIFont(name: "Arial Unicode MS", size: 120)!], context: nil)
        return min(self.cellSize.width / calcBounds.width, self.cellSize.height / calcBounds.height)
    }()
    
    public init(size: CGSize, rows: Int, cols: Int) {
        initialSize = size
        grid = CGSize(rows: rows, cols: cols)
        cellSize = CGSize(width: CGFloat(size.width) / CGFloat(cols), height: CGFloat(size.height) / CGFloat(rows))
        super.init(size: size)
        anchorPoint = CGPoint(x: 0, y: 0)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RogueScene {
    public func setCell(x: Int, y: Int, code: UInt32, bgColor: CGColor, fgColor: CGColor) {
        cells[x][y].fgcolor = UIColor(cgColor: fgColor)
        cells[x][y].bgcolor = UIColor(cgColor: bgColor)
        
        if let glyph = UnicodeScalar(code) {
            cells[x][y].glyph = getTexture(glyph: String(glyph))
        }
    }
    
    override public func sceneDidLoad() {
        for x in 0...grid.cols {
            var row = [Cell]()
            for y in 0...grid.rows {
                let newCell = Cell(x: CGFloat(x) * cellSize.width, y: CGFloat(grid.rows - y - 1) * cellSize.height, size: CGSize(width: cellSize.width, height: cellSize.height))
                row.append(newCell)
            }
            cells.append(row);
        }
    }
    
    override public func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0, y: 0)
        
        for x in 0...grid.cols-1 {
            for y in 0...grid.rows-1 {
                cells[x][y].background.anchorPoint = CGPoint(x: 0, y: 0)
                addChild(cells[x][y].background)
                addChild(cells[x][y].foreground)
            }
        }
    }
}

fileprivate extension RogueScene {

    // Create/find glyph textures
    func getTexture(glyph: String) -> SKTexture {
        return textureMap[glyph] ?? addTexture(glyph: glyph)
    }
    
    func createTextureFromGlyph(glyph: String, size: CGSize) -> SKTexture {
        // Apple Symbols provides U+26AA, for rings, which Arial does not.
        
        enum GlyphType {
            case letter
            case ring
            case glyph
            case foliage
            
            var fontName: String {
                switch self {
                case .ring:
                    return "Symbol"
                case .letter:
                    return "Monaco"
                default:
                    return "ArialUnicodeMS"
                }
            }
            
            var scaleFactor: CGFloat {
                return 1
            }
            
            var drawingOptions: NSStringDrawingOptions {
                return [.usesFontLeading]
            }
            
            // TODO: fix charm
            init(glyph: String) {
                // We want to use pretty font/centering if we can, but
                // it makes tExT LOOk liKe THiS so we're defining characters
                // that will be rendered at the same lineheight
                // Note: Items "call"ed with non-standard characters aren't covered
                // If some characters become ugly, this list can be expanded
                switch (glyph) {
                case "a"..."z",
                     "A"..."Z",
                     "0"..."9",
                     "!"..."?",
                     " ", "[", "/", "]", "^", "{", "|", "}", "~", "@":
                    self = .letter
                case "\(UnicodeScalar(UInt32(FOLIAGE_CHAR))!)":
                    self = .foliage
                case "\(UnicodeScalar(UInt32(RING_CHAR))!)":
                    self = .ring
                default:
                    self = .glyph
                }
            }
        }
        
        let glyphType = GlyphType(glyph: glyph)
        // Find ideal size for text
        let fontSize: CGFloat = 130 // Base size, we'll calculate from here
        let calcFont = UIFont(name: glyphType.fontName, size: fontSize)!
        
        var surface: UIImage {
            // Calculate font scale factor
            var scaleFactor: CGFloat {
                let calcAttributes = [NSFontAttributeName: calcFont]
                // If we calculate with the descender, the line height will be centered incorrectly for letters
                let calcOptions = glyphType.drawingOptions
                let calcBounds = glyph.boundingRect(with: CGSize(), options: calcOptions, attributes: calcAttributes, context: nil)
                let rawScaleFactor = min(size.width / calcBounds.width, size.height / calcBounds.height)
                let clampedScaleFactor = max(maxScaleFactor * 0.8, min(rawScaleFactor, maxScaleFactor * 1.2)) // Within 20% of original
                
                return clampedScaleFactor * (glyphType.scaleFactor) // Shrink certain non-letters
            }
            
            // Actual font that we're going to render
            let font = UIFont(name: glyphType.fontName, size: fontSize * scaleFactor)!
            let fontAttributes = [
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: SKColor.white // White so we can blend it
            ]
            
            let realBounds: CGRect = glyph.boundingRect(with: CGSize(), options: glyphType.drawingOptions, attributes: fontAttributes, context: nil)
            let stringOrigin = CGPoint(x: (size.width - realBounds.width)/2 - realBounds.origin.x + 1, y:
                                           font.descender - realBounds.origin.y + (size.height - realBounds.height)/2)
           
            UIGraphicsBeginImageContext(size)
            glyph.draw(at: stringOrigin, withAttributes: fontAttributes)
            let surface = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return surface!
        }
    
        return SKTexture(image: surface)
    }
    
    func addTexture(glyph: String) -> SKTexture {
        textureMap[glyph] = createTextureFromGlyph(glyph: glyph, size: cellSize)
        return textureMap[glyph]!
    }
}