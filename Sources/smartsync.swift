// The Swift Programming Language

import Foundation
import ArgumentParser
import Spinner
import ColorizeSwift


let version = "v2.0.0"
let appInfo = "SmartSync " + version
var currentHost = Host.current().localizedName ?? ""
let logfileName = "smartsync.log"
var smartsyncLogData = appInfo

struct SmartSyncConfig: Decodable {
    var remoteHost: String
    var logDirectory: String
    var directories: [Directories]
}

struct Directories : Decodable {
    var name: String
    var sourceDir: String
}

enum SmartSyncError: Error {
    case rsyncError(String)
}


@main
struct smartsync: ParsableCommand {
    @Flag(help: "Dry-Run only, no files are backed-up.")
    var dryRun = false
    
    func run() throws {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = " - HH:mm dd.MM.YYYY"
        
        print(appInfo.bold + dateFormatter.string(from: date).darkGray())
        smartsyncLogData.append(" - " + dateFormatter.string(from: date))
        
        if dryRun {
            print("\n" + "This is only a Dry-Run only, no files are backed-up.".backgroundColor(.orange1))
            smartsyncLogData.append("\n\nThis is only a Dry-Run only, no files are backed-up.")
        }
        
        guard let mySmartSyncConfig = readConfigFile() else {
            fatalError("config.json file not found")
        }
        
        guard FileManager.default.fileExists(atPath: "/usr/bin/rsync") else {
            fatalError("rsync not installed")
        }
        
        let info1 = "\nUser: " + NSUserName() + " | local Host: " + currentHost + " | remote Host: " + (mySmartSyncConfig.remoteHost)
        let info2 = "Backing up " + String(mySmartSyncConfig.directories.count) + " directories"
        let info3 = "Logs in: " + mySmartSyncConfig.logDirectory + "\n"
        
        print(info1.cyan)
        print(info2.cyan)
        print(info3.cyan)
        smartsyncLogData.append("\n" + info1 + "\n" + info2 + "\n" + info3)
        
        for dir in mySmartSyncConfig.directories {
            let s = Spinner(.aesthetic, "backing up: " + dir.name, color: .cyan)
            s.start()
            
            if FileManager.default.fileExists(atPath: dir.sourceDir) {
                do {
                    try callRsync(remoteHost: mySmartSyncConfig.remoteHost, dryRun: dryRun, logDirectory: mySmartSyncConfig.logDirectory, backupItem: dir)
                    s.success(dir.name + ": backed up sucessfully".foregroundColor(.chartreuse2))
                } catch {
                    s.error(dir.name + ": an error occured!".foregroundColor(.red3_2))
                    smartsyncLogData.append("\nan error occurred")
                }
            } else {
                s.warning(dir.name + ": directory is not mounted and has been ignored".darkGray())
                smartsyncLogData.append("\n# " + dir.name)
                smartsyncLogData.append("\ndirectory is not mounted and has been ignored")
            }
            
            s.clear()
        }
        
        writeSmartSyncLog(logDirectory: mySmartSyncConfig.logDirectory, logData: smartsyncLogData)
        
        print("\n")
    }
}


//@discardableResult // Add to suppress warnings when you don't want/need a result
func safeShell(_ command: String) throws -> (standardOutput: String, errorOutput: String, returnCode: Int32?) {
    let task = Process()
    let pipe = Pipe()
    let pipeERROR = Pipe()
    var returnCode: Int32? = nil
    
    task.standardOutput = pipe
    task.standardError = pipeERROR
    task.arguments = ["-c", command]
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.standardInput = nil

    do {
        try task.run()
        task.waitUntilExit()
    } catch {
        print("Failed to run with Error \(error)")
    }
    
    returnCode = task.terminationStatus
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    
    let dataERROR = pipeERROR.fileHandleForReading.readDataToEndOfFile()
    let outputERROR = String(data: dataERROR, encoding: .utf8)!
    
    return (standardOutput: output, errorOutput: outputERROR, returnCode: returnCode)
}


func readConfigFile() -> SmartSyncConfig? {
    let applicationSupportFolderURL = try! FileManager.default.url(for: .userDirectory,
                                                                    in: .localDomainMask,
                                                        appropriateFor: nil,
                                                                create: false)

    do {
        let jsonDataURL = applicationSupportFolderURL.appendingPathComponent(NSUserName() + "/.smartSync/config.json")
    
        let data = try Data(contentsOf: jsonDataURL)
        let decoder = JSONDecoder()
        let config = try decoder.decode(SmartSyncConfig.self, from: data)
        
        return config
    } catch {
        print(error.localizedDescription)
        return nil
    }
}


func callRsync(remoteHost: String, dryRun: Bool, logDirectory: String, backupItem: Directories) throws {
    let escapedName = backupItem.name.replacingOccurrences(of: " ", with: "")
    let targetDir = NSUserName() + "@" + remoteHost + "::home/SMARTSYNC/" + currentHost
    
    var toggleTest: String = "--delete"
    if dryRun {
        toggleTest = "--dry-run"
    }
    
    let rsyncCmd = "/usr/bin/rsync -aq " + toggleTest + " --password-file=/Users/" + NSUserName() + "/.smartSync/key --log-file=" + logDirectory + "/smartsync-" + escapedName + ".log \"" + backupItem.sourceDir + "\" \"" + targetDir + "\" 2>" + logDirectory + "/smartsync-" + escapedName + ".log"
    
    //print(rsyncCmd)
    smartsyncLogData.append("\n# " + backupItem.name)
    smartsyncLogData.append("\n" + backupItem.sourceDir)
    smartsyncLogData.append("\n" + rsyncCmd + "\n")
    
    do {
        let o = try safeShell(rsyncCmd)
        
        if (o.returnCode == 0) {
            //print("OUTPUT:")
            //print(o.standardOutput)
        } else {
            //print("ERROR: " + o.errorOutput)
            //print("STATUS: " , o.returnCode ?? 0)
            throw SmartSyncError.rsyncError("an error occurred while running rsync (return code: " + String(Int(o.returnCode!)) + ") - see the log file for details")
        }
    } catch {
        throw SmartSyncError.rsyncError("an error occurred while running rsync - see the log file for details")
    }
}

func writeSmartSyncLog(logDirectory: String, logData: String) {
    let logfilePath = logDirectory + "/" + logfileName
    
    _ = FileManager.default.createFile(atPath: logfilePath, contents: logData.data(using: .utf8))
}

