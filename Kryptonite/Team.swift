//
//  Team.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import JSON

struct Team {

    /// The team's information
    struct Info:Jsonable {
        let name:String
        
        init(name:String) {
            self.name = name
        }
        
        init(json: Object) throws {
            try self.init(name: json ~> "name")
        }
        
        var object: Object {
            return ["name": name]
        }
    }

    
    /// the team's policy settings
    struct PolicySettings:Jsonable {
        let temporaryApprovalSeconds:UInt64?
        
        static var defaultSettings:PolicySettings {
            return PolicySettings(temporaryApprovalSeconds: UInt64(Properties.Interval.threeHours.rawValue))
        }
        
        init(temporaryApprovalSeconds:UInt64?) {
            self.temporaryApprovalSeconds = temporaryApprovalSeconds
        }
        
        init(json: Object) throws {
            self.init(temporaryApprovalSeconds: try? json ~> "temporary_approval_seconds")
        }
        
        var object: Object {
            if let seconds = temporaryApprovalSeconds {
                return ["temporary_approval_seconds": seconds]
            }
            
            return [:]
        }
    }
    
    struct MemberIdentity:Jsonable {
        let publicKey:SodiumPublicKey
        let email:String
        let sshPublicKey:Data
        let pgpPublicKey:Data
        
        init(publicKey:SodiumPublicKey, email:String, sshPublicKey:Data, pgpPublicKey:Data) {
            self.publicKey = publicKey
            self.email = email
            self.sshPublicKey = sshPublicKey
            self.pgpPublicKey = pgpPublicKey
        }
        
        init(json: Object) throws {
            try self.init(publicKey: SodiumPublicKey(((json ~> "public_key") as String).fromBase64()),
                          email: json ~> "email",
                          sshPublicKey: ((json ~> "ssh_public_key") as String).fromBase64(),
                          pgpPublicKey: ((json ~> "pgp_public_key") as String).fromBase64())
            
        }
        
        var object: Object {
            return ["public_key": publicKey.toBase64(),
                    "email": email,
                    "ssh_public_key": sshPublicKey.toBase64(),
                    "pgp_public_key": pgpPublicKey.toBase64()]
        }
    }
    
    let id:String
    var info:Info
    let publicKey:SodiumPublicKey
    var policy:PolicySettings
    
    var name:String {
        return info.name
    }

    init(name:String, publicKey:SodiumPublicKey) throws {
        try self.init(info: Info(name: name), publicKey: publicKey)
    }

    init(info:Info, publicKey:SodiumPublicKey, policy:PolicySettings = PolicySettings.defaultSettings) throws {
        self.id = try Data.random(size: 32).toBase64()
        self.info = info
        self.publicKey = publicKey
        self.policy = policy
    }
    
    init(json: Object) throws {
        try self.init(info: Info(json: json ~> "info"),
                      publicKey: SodiumPublicKey(((json ~> "public_key") as String).fromBase64()),
                      policy: PolicySettings(json: json ~> "policy"))
    }
    
    var object: Object {
        return ["info": info.object,
                "public_key": publicKey.toBase64(),
                "policy": policy.object]
    }
    
    /// team keychain
    
    enum TeamKeychainStorageKeys:String {
        case lastBlockHash = "last_block_hash"
        case adminPublicKey = "admin_public_key"
        case adminSecretKey = "admin_secret_key"
    }
    
    var keychain:KeychainStorage {
        return KeychainStorage(service: "team_\(id)_\(self.publicKey.toBase64())")
    }
    
    /// get/set last block hash
    
    func set(lastBlockHash:Data) throws {
        try self.keychain.setData(key: TeamKeychainStorageKeys.lastBlockHash.rawValue, data: lastBlockHash)
    }
    
    func getLastBlockHash() throws -> Data? {
        do {
            return try self.keychain.getData(key: TeamKeychainStorageKeys.lastBlockHash.rawValue)
        } catch KeychainStorageError.notFound {
            return nil
        }
    }

    /// get/set admin key pair
    func setAdmin(keypair:SodiumKeyPair) throws {
        try self.keychain.setData(key: TeamKeychainStorageKeys.adminPublicKey.rawValue, data: keypair.publicKey)
        try self.keychain.setData(key: TeamKeychainStorageKeys.adminSecretKey.rawValue, data: keypair.secretKey)
    }
    
    func getAdmin() throws -> SodiumKeyPair? {
        do {
            let publicKey = try self.keychain.getData(key: TeamKeychainStorageKeys.adminPublicKey.rawValue)
            let secretKey = try self.keychain.getData(key: TeamKeychainStorageKeys.adminSecretKey.rawValue)
            
            return SodiumKeyPair(publicKey: publicKey, secretKey: secretKey)
        } catch KeychainStorageError.notFound {
            return nil
        }
    }
    
    var isAdmin:Bool {
        return (try? getAdmin()) != nil
    }

}
