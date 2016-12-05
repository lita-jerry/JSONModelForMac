//
//  AppDelegate.swift
//  JSONModelForMac
//
//  Created by Jerry on 2016/11/30.
//  Copyright © 2016年 github.com/JerryLoveRice. All rights reserved.
//

import Cocoa

struct ModelCache {
    var className: String
    var funcPrefix: String
    var isSwift: Bool
    var models: [Model]
    init(_ className: String, _ funcPrefix: String, _ isSwift: Bool, _ models: [Model]) {
        self.className = className
        self.funcPrefix = funcPrefix
        self.isSwift = isSwift
        self.models = models
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    @IBOutlet var JSONInputTextView:  NSTextView!
    @IBOutlet var JSONOutputTextView: NSTextView!
    
    @IBOutlet weak var classNameInputTextField:  NSTextField! //类名
    @IBOutlet weak var funcPrefixInputTextField: NSTextField! //解析方法前缀
    
    @IBOutlet weak var programLanguageSegmentedControl: NSSegmentedControl!
    
    var modelCache: ModelCache? //作为model的缓存，不用每次解析JSON串，只需对model缓存转字符串操作即可
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        let data = NSData.init(contentsOfFile: Bundle.main.path(forResource: "json_test", ofType: nil)!)
        let string = String.init(data: data as! Data, encoding: String.Encoding.utf8)
        
        self.classNameInputTextField.stringValue = "testModel"
        self.funcPrefixInputTextField.stringValue = "instanceWithJSON"
        self.JSONInputTextView.string = string
        self.JSONOutputTextView.font = NSFont.userFixedPitchFont(ofSize: 11)
        self.JSONOutputTextView.string = ""
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func transformationBTNClick(_ sender: Any) {
        
        let updateModelCache = self.updateModelCache() //用来保存更新的状态
        
        if(updateModelCache.isSuccess){
            if(self.programLanguageSegmentedControl.selectedSegment == 0){ /*Swift*/
                    let modelString = "/* \(modelCache!.className).swift 文件 */\n\n" +
                        JSONModel.makeSwiftHead(modelCache!) +
                        JSONModel.makeSwiftVariable(modelCache!) +
                        JSONModel.makeSwiftInstance(modelCache!) +
                        JSONModel.makeSwiftTail()
                    self.JSONOutputTextView.string = modelString
            }else{ /*OC*/
                if(modelCache != nil){
                    let modelString_h = "/* \(modelCache!.className).h 文件 */\n\n" +
                        JSONModel.makeOCHHead(modelCache!) +
                        JSONModel.makeOCHVariable(modelCache!) +
                        JSONModel.makeOCHInstance(modelCache!) +
                        JSONModel.makeOCHTail()
                    
                    let modelString_m = "\n\n/* \(modelCache!.className).m 文件 */\n\n" +
                        JSONModel.makeOCMHead(modelCache!, fileName: modelCache!.className) +
                        JSONModel.makeOCMInstance(modelCache!) +
                        JSONModel.makeOCMTail()
                    self.JSONOutputTextView.string = modelString_h + modelString_m
                }
            }
        }else{
            self.JSONOutputTextView.string = updateModelCache.message
        }
    }
    
    @IBAction func saveFileBTNClick(_ sender: Any) {
        
        //如果缓存为空，先更新缓存，然后再次执行本方法(递归)
        guard modelCache != nil else {
            let updateModelCache = self.updateModelCache() //用来保存更新的状态
            if(updateModelCache.isSuccess){
                saveFileBTNClick(sender)
            }else{
                self.JSONOutputTextView.string = updateModelCache.message
            }
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.message = "请选择保存的位置"
        
        if(self.programLanguageSegmentedControl.selectedSegment == 0/*Swift*/){
            savePanel.allowedFileTypes = ["swift"]
            savePanel.nameFieldStringValue = "\(self.classNameInputTextField.stringValue)"
            
            savePanel.beginSheetModal(for: NSApp.mainWindow!, completionHandler: {(result) in
                if(result == NSFileHandlingPanelOKButton){
                    NSLog("\(savePanel.url!)")
                    
                    var value: String?
                    
                    value = "/* \(self.modelCache!.className).swift 文件 */\n\n" +
                        JSONModel.makeSwiftHead(self.modelCache!) +
                        JSONModel.makeSwiftVariable(self.modelCache!) +
                        JSONModel.makeSwiftInstance(self.modelCache!) +
                        JSONModel.makeSwiftTail()
                    
                    let data: NSData = NSData(data: value!.data(using: String.Encoding.utf8)!)
                    
                    data.write(to: savePanel.url!, atomically: false)
                    
                    let _url = savePanel.url!
                    print("\(_url)")
                    NSWorkspace.shared().activateFileViewerSelecting([_url])
                }
            })
        }else{/*OC*/
            savePanel.allowedFileTypes = ["h"]
            savePanel.nameFieldStringValue = "\(self.classNameInputTextField.stringValue)"
            
            savePanel.beginSheetModal(for: NSApp.mainWindow!, completionHandler: {(result) in
                if(result == NSFileHandlingPanelOKButton){
                    NSLog("\(savePanel.url!)")
                    
                    let string_h = "/* \(self.modelCache!.className).h 文件 */\n\n" +
                        JSONModel.makeOCHHead(self.modelCache!) +
                        JSONModel.makeOCHVariable(self.modelCache!) +
                        JSONModel.makeOCHInstance(self.modelCache!) +
                        JSONModel.makeOCHTail()
                    
                    let string_m = "/* \(self.modelCache!.className).m 文件 */\n\n" +
                        JSONModel.makeOCMHead(self.modelCache!, fileName: savePanel.nameFieldStringValue) +
                        JSONModel.makeOCMInstance(self.modelCache!) +
                        JSONModel.makeOCMTail()
                    
                    //.h
                    let data_h: NSData = NSData(data: string_h.data(using: String.Encoding.utf8)!)
                    let writeOCHIsSuccess = data_h.write(to: savePanel.url!, atomically: false)
                    //.m
                    let data_m: NSData = NSData(data: string_m.data(using: String.Encoding.utf8)!)
                    //.h换成.m(以.h分割成数组,变相的把.h去掉了,然后再追加.m)
                    let url_m = savePanel.url!.path.components(separatedBy: ".h").first!.appending(".m")
                    let writeOCMIsSuccess =  data_m.write(to: URL(fileURLWithPath: url_m), atomically: false)
                    
                    if(writeOCHIsSuccess && writeOCMIsSuccess){
                        let _url = [savePanel.url!, URL(fileURLWithPath: url_m)]
                        print("\(_url)")
                        NSWorkspace.shared().activateFileViewerSelecting(_url)
                    }
                }
            })
        }
    }
    
    //切换编程语言的时候,自动进行转换
    @IBAction func programLanguageChangeAction(_ sender: NSSegmentedControl) {
        self.transformationBTNClick(sender)
    }
    
    
    /// 刷新缓存
    ///
    /// - Returns: 是否刷新成功
    func updateModelCache() -> (isSuccess: Bool, message: String?) {
        
        let className: String? = self.classNameInputTextField.stringValue
        guard (className != nil) && (className!.utf8.count > 0) else {
            return (false, "类名不能为空")
        }
        let funcPrefix: String? = self.funcPrefixInputTextField.stringValue
        guard (funcPrefix != nil) && (funcPrefix!.utf8.count > 0) else {
            return (false, "构造函数前缀不能为空")
        }
        let JSON: String? = self.JSONInputTextView.string
        guard (JSON != nil) && (JSON!.utf8.count > 0) else {
            return (false, "JSON不能为空")
        }
        let isSwift = self.programLanguageSegmentedControl.selectedSegment == 0
        
        let returnValue = JSONModel.toModels(JSON:JSON!, isSwift: isSwift, className: className!, funcPrefix: funcPrefix!)
        if(returnValue.error != nil){
            return (false, returnValue.error)
        }else if ((returnValue.value?.count)! <= 0){
            return (false, "JSON元素为空")
        }else{
            self.modelCache = ModelCache(className!, funcPrefix!, isSwift, returnValue.value!)
            return (true, nil)
        }
    }
    
    //MARK: - 菜单
    //菜单保存
    @IBAction func saveMenuClick(_ sender: NSMenuItem) {
        self.saveFileBTNClick(sender)
    }
    
    @IBAction func clearAllMenuClick(_ sender: Any) {
        self.JSONOutputTextView.string = " "
        self.JSONInputTextView.string = ""
    }
    
    //MARK: - APPDelegate
    //点击Dock重新显示窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if (!flag){
            //主窗口显示
            NSApp.activate(ignoringOtherApps: false)
            self.window.makeKeyAndOrderFront(self)
        } 
        return true
    }

}

