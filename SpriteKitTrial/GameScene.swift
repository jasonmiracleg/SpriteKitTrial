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
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        jumpDirection = location.x < frame.midX ? -1 : 1
        showJumpGuide()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        jumpDirection = location.x < frame.midX ? -1 : 1
        showJumpGuide()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Restart button logic
        let nodesAtPoint = nodes(at: location)
        if nodesAtPoint.contains(where: { $0.name == "restartButton" }) {
            print("Restart tapped!")
            restartScene()
            return
        }

        // Check player movement to determine if jump is allowed
        let velocity = player.physicsBody?.velocity ?? .zero
        print("Velocity: \(velocity)")
        let speedThreshold: CGFloat = 1
        let isIdle = abs(velocity.dy) < speedThreshold

        let currentTime = CACurrentMediaTime()
        let timeSinceLastTap = currentTime - lastTapTime
        lastTapTime = currentTime

        if isIdle {
            // Jump
            let jumpStrengthY: CGFloat = 800
            let jumpStrengthX: CGFloat = 200 * jumpDirection

            player.physicsBody?.velocity = CGVector(dx: jumpStrengthX, dy: jumpStrengthY)
            print("[touchesEnded] Jumping with dx: \(jumpStrengthX), dy: \(jumpStrengthY)")
        } else {
            // Spin!
            let spinBoost = max(2.0, 10.0 - timeSinceLastTap * 10) // faster tap = higher boost
            player.physicsBody?.angularVelocity += spinBoost
            print("[touchesEnded] Rotating mid-air with boost: \(spinBoost)")
        }

        jumpDirection = 0
        removeJumpGuide()
    }

    override func update(_ currentTime: TimeInterval) {
        if player.position.y > frame.midY {
            camera?.position.y = player.position.y

            platforms = platforms.filter {
                $0.position.y > camera!.position.y - 400
            }
            while platforms.count < 10 {
                let x = CGFloat.random(in: 50...frame.width - 50)
                let y = (platforms.last?.position.y ?? 0) + 100
                let newPlatform = createPlatform(at: CGPoint(x: x, y: y))
                platforms.append(newPlatform)
            }
        }

        if player.position.x < -50 {
            player.position.x = frame.width + 50
        } else if player.position.x > frame.width + 50 {
            player.position.x = -50
        }
    }

    func showJumpGuide() {
        jumpGuide?.removeFromParent()

        let path = CGMutablePath()
        let start = player.position
        let jumpVelocity = CGVector(dx: 200 * jumpDirection, dy: 800)
        let gravity = physicsWorld.gravity
        let dt: CGFloat = 0.1
        var position = start
        var velocity = jumpVelocity

        path.move(to: position)

        for _ in 0..<30 {
            velocity.dx += gravity.dx * dt
            velocity.dy += gravity.dy * dt
            position.x += velocity.dx * dt
            position.y += velocity.dy * dt
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
        player.position = CGPoint(x: frame.midX, y: frame.midY)

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
        for i in 0..<10 {
            let x = CGFloat.random(in: 50...frame.width - 50)
            let y = CGFloat(i) * 100 + 100
            let platform = createPlatform(at: CGPoint(x: x, y: y))
            platforms.append(platform)
        }
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
