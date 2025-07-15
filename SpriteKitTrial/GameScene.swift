//
//  GameScene.swift
//  SpriteKitTrial
//
//  Created by Jason Miracle Gunawan on 11/07/25.
//

import GameplayKit
import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    var player: SKShapeNode!
    var platforms: [SKSpriteNode] = []
    var jumpDirection: CGFloat = 0
    var jumpGuide: SKShapeNode?
    var restartButton: SKLabelNode!
    var lastTapTime: TimeInterval = 0
    var leftWall: SKNode!
    var rightWall: SKNode!
    var lastPlatformX: CGFloat = 0
    
    var startPos: CGPoint?
    var currentPos: CGPoint?

    let playerCategory: UInt32 = 0x1 << 0
    let platformCategory: UInt32 = 0x1 << 1

    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -5)
        backgroundColor = .cyan

        let cam = SKCameraNode()
        cam.position = CGPoint(x: frame.midX, y: frame.midY)
        camera = cam
        addChild(cam)

        createPlayer()
        createInitialPlatforms()
        createRestartButton()
        createInitialBounceWalls()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        jumpDirection = location.x < frame.midX ? -1 : 1
        
        startPos = touch.location(in: self)
        
        showJumpGuide(with: touch.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        jumpDirection = location.x < frame.midX ? -1 : 1
        
        currentPos = touch.location(in: self)
        
        showJumpGuide(with: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let start = startPos else { return }
        let location = touch.location(in: self)

        // Restart button logic
        let nodesAtPoint = nodes(at: location)
        if nodesAtPoint.contains(where: { $0.name == "restartButton" }) {
            print("Restart tapped!")
            restartScene()
            return
        }

        // Measure velocity and check if player is idle enough to jump
        let velocity = player.physicsBody?.velocity ?? .zero
        print("Velocity: \(velocity)")

        let speedThreshold: CGFloat = 1
        let isIdle = abs(velocity.dy) < speedThreshold

        // Time since last tap for spin boost
        let currentTime = CACurrentMediaTime()
        let timeSinceLastTap = currentTime - lastTapTime
        lastTapTime = currentTime

        // Calculate jump strength from horizontal drag distance
        let dx = location.x - start.x
        let jumpStrengthX = dx * 4  // Adjust the multiplier as needed
        let jumpStrengthY: CGFloat = 800

        if isIdle {
            // Apply jump
            player.physicsBody?.velocity = CGVector(dx: jumpStrengthX, dy: jumpStrengthY)
            print("[touchesEnded] Jumping with dx: \(jumpStrengthX), dy: \(jumpStrengthY)")
        } else {
            // Apply mid-air spin
            let spinBoost = max(1.0, 10.0 - timeSinceLastTap)
            player.physicsBody?.angularVelocity = spinBoost
            print("[touchesEnded] Rotating mid-air with boost: \(spinBoost)")
        }

        // Cleanup
        jumpDirection = 0
        startPos = nil
        removeJumpGuide()
    }

    override func update(_ currentTime: TimeInterval) {
        if player.position.y > frame.midY {
            
            if let camera = camera {
                // 1. Determine the lowest visible platform Y
                let lowestPlatformY = platforms.map { $0.position.y }.min() ?? 0

                // 2. Set a minimum camera Y position — e.g., just below the lowest platform
                let minCameraY = lowestPlatformY + 200

                if player.position.y > camera.position.y {
                    camera.position.y = player.position.y
                } else if player.position.y < camera.position.y {
                    // But don't let camera fall below minCameraY
                    camera.position.y = max(player.position.y, minCameraY)
                }
            }
            
            updateBounceWalls()
            
            if let camY = camera?.position.y {
                platforms = platforms.filter { platform in
                    if platform.position.y > camY - frame.height - 200 {
                        return true // keep this platform
                    } else {
                        platform.removeFromParent() // remove from the scene
                        return false // filter it out of the array
                    }
                }
            }
            
            while platforms.count < 10 {
                var x: CGFloat
                repeat {
                    x = CGFloat.random(in: 50...frame.width - 50)
                } while abs(x - lastPlatformX) < 80

                let y = (platforms.last?.position.y ?? 0) + 200
                let newPlatform = createPlatform(at: CGPoint(x: x, y: y))
                platforms.append(newPlatform)
                lastPlatformX = x // ✅ keep track for next
            }
        }

        if player.position.x < -50 {
            player.position.x = frame.width + 50
        } else if player.position.x > frame.width + 50 {
            player.position.x = -50
        }
    }

    func showJumpGuide(with currentPos: CGPoint) {
        guard let startPos = startPos else { return }
        jumpGuide?.removeFromParent()

        let path = CGMutablePath()
        let start = player.position
        let dx = currentPos.x - startPos.x
        let jumpVelocity = CGVector(dx: dx * 4, dy: 800)
        let gravity = physicsWorld.gravity
        let dt: CGFloat = 0.1
        var position = start
        var velocity = jumpVelocity

        path.move(to: position)
        
        let minX = CGFloat(0)
        let maxX = CGFloat(frame.width)
        

        for _ in 0..<30 {
            velocity.dx += gravity.dx * dt
            velocity.dy += gravity.dy * dt
            position.x += velocity.dx * dt
            position.y += velocity.dy * dt
            
            if position.x <= minX || position.x >= maxX {
                velocity.dx *= -1
                position.x = position.x <= minX ? minX : maxX
            }
            
            path.addLine(to: position)
        }

        let arc = SKShapeNode(path: path)
        arc.strokeColor = .orange
        arc.lineWidth = 2
        arc.zPosition = 100

        jumpGuide = arc
        addChild(arc)
    }

    func removeJumpGuide() {
        jumpGuide?.removeFromParent()
        jumpGuide = nil
    }

    func createPlayer() {
        player = SKShapeNode(rectOf: CGSize(width: 20, height: 40), cornerRadius: 8)
        player.fillColor = .gray
        player.position = CGPoint(x: frame.midX, y: 100)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 40))
        body.linearDamping = 1.0
        body.friction = 1.0
        body.restitution = 0.0
        body.allowsRotation = true
        body.categoryBitMask = playerCategory
        body.contactTestBitMask = platformCategory
        body.collisionBitMask = platformCategory

        player.physicsBody = body
        addChild(player)
    }

    func createPlatform(at position: CGPoint) -> SKSpriteNode {
        let platform = SKSpriteNode(color: .brown, size: CGSize(width: 100, height: 20))
        platform.position = position

        let body = SKPhysicsBody(rectangleOf: platform.size)
        body.isDynamic = false
        body.contactTestBitMask = playerCategory
        body.collisionBitMask = playerCategory
        body.categoryBitMask = platformCategory
        body.friction = 1.0

        platform.physicsBody = body
        addChild(platform)

        return platform
    }

    func createInitialPlatforms() {
        lastPlatformX = frame.midX

        for i in 0..<10 {
            let y = CGFloat(i) * 200 + 50
            var x: CGFloat

            if i == 0 {
                // First platform is centered
                x = frame.midX
            } else {
                repeat {
                    x = CGFloat.random(in: 50...frame.width - 50)
                } while abs(x - lastPlatformX) < 80  // Avoid too-similar x values
            }

            let platform = createPlatform(at: CGPoint(x: x, y: y))
            platforms.append(platform)
            lastPlatformX = x
        }
    }

    func createInitialBounceWalls() {
        let wallThickness: CGFloat = 1
        
        leftWall = SKNode()
        leftWall.position = CGPoint(x : 0, y: frame.minY)
        leftWall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: wallThickness, height: frame.height))
        leftWall.physicsBody?.isDynamic = false
        leftWall.physicsBody?.restitution = 1
        addChild(leftWall)
        
        rightWall = SKNode()
        rightWall.position = CGPoint(x : frame.width, y: frame.minY)
        rightWall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: wallThickness, height: frame.height))
        rightWall.physicsBody?.isDynamic = false
        rightWall.physicsBody?.restitution = 1
        addChild(rightWall)
        
        updateBounceWalls()
    }
    
    func updateBounceWalls() {
        guard let camY = camera?.position.y else { return }
        let wallHeight : CGFloat = frame.height
        let wallThickness: CGFloat = 1
        
        leftWall.position = CGPoint(x : 0, y: camY)
        rightWall.position = CGPoint(x : frame.width, y: camY)
        
        leftWall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: wallThickness, height: wallHeight))
        leftWall.physicsBody?.isDynamic = false
        leftWall.physicsBody?.restitution = 1.0

        rightWall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: wallThickness, height: wallHeight))
        rightWall.physicsBody?.isDynamic = false
        rightWall.physicsBody?.restitution = 1.0
    }
    
    func createRestartButton() {
        restartButton = SKLabelNode(text: "Restart")
        restartButton.fontName = "AvenirNext-Bold"
        restartButton.fontSize = 32
        restartButton.fontColor = .white
        restartButton.position = CGPoint(x: frame.midX, y: camera!.position.y - 200)
        restartButton.zPosition = 1000
        restartButton.name = "restartButton"

        camera?.addChild(restartButton)
    }

    func restartScene() {
        if let currentScene = self.scene {
            let newScene = GameScene(size: currentScene.size)
            newScene.scaleMode = currentScene.scaleMode
            let transition = SKTransition.fade(withDuration: 0.5)
            view?.presentScene(newScene, transition: transition)
        }
    }
}
