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
    var isPlayerGrounded = false

    let playerCategory: UInt32 = 0x1 << 0
    let platformCategory: UInt32 = 0x1 << 1

    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -5)
        physicsWorld.contactDelegate = self
        backgroundColor = .cyan

        let cam = SKCameraNode()
        cam.position = CGPoint(x: frame.midX, y: frame.midY)
        camera = cam
        addChild(cam)

        createPlayer()
        createInitialPlatforms()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Determine direction: left or right
        if location.x < frame.midX {
            jumpDirection = -1
        } else {
            jumpDirection = 1
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPlayerGrounded {
            let jumpStrengthY: CGFloat = 800
            let jumpStrengthX: CGFloat = 200 * jumpDirection

            player.physicsBody?.velocity = CGVector(
                dx: jumpStrengthX,
                dy: jumpStrengthY
            )
            isPlayerGrounded = false
        }

        jumpDirection = 0
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

    func didEnd(_ contact: SKPhysicsContact) {
        if contact.bodyA.categoryBitMask == platformCategory
            || contact.bodyB.categoryBitMask == platformCategory
        {
            isPlayerGrounded = false
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        if contact.bodyA.categoryBitMask == platformCategory
            || contact.bodyB.categoryBitMask == platformCategory
        {
            isPlayerGrounded = true
        }
    }

    func createPlayer() {
        player = SKShapeNode(
            rectOf: CGSize(width: 20, height: 40),
            cornerRadius: 8
        )
        player.fillColor = .gray
        player.position = CGPoint(x: frame.midX, y: frame.midY)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 40))

        body.restitution = 0.0
        body.allowsRotation = true
        body.categoryBitMask = playerCategory
        body.contactTestBitMask = platformCategory
        body.collisionBitMask = platformCategory

        player.physicsBody = body

        addChild(player)
    }

    func createPlatform(at position: CGPoint) -> SKSpriteNode {
        let platform = SKSpriteNode(
            color: .brown,
            size: CGSize(width: 100, height: 20)
        )
        platform.position = position

        let body = SKPhysicsBody(rectangleOf: platform.size)
        body.isDynamic = false
        body.contactTestBitMask = playerCategory
        body.collisionBitMask = playerCategory
        body.categoryBitMask = platformCategory

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
}
