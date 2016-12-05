//
//  JSONModel.swift
//  JSONModelForMac
//
//  Created by Jerry on 2016/11/30.
//  Copyright © 2016年 github.com/JerryLoveRice. All rights reserved.
//

import Cocoa

///节点模型
class Model: NSObject {
    var name: String?
    var type: keyType!
    var subModel: [Model]?
    init(_ name: String?, _ type: keyType!, _ subModel: [Model]?) {
        self.name = name
        self.type = type
        self.subModel = subModel
    }
}

/// 节点的类型
enum keyType: Int {
    case string = 1
    case integer //
    case float   //浮点类型
    case bool    //布尔类型
    case array   //有序的集合
    case object  //包含key/value的无序集合
    case unknow  //未知类型,例如null
}

class JSONModel: NSObject {
    ///JSON转模型
    class func toModels(JSON : String, isSwift: Bool, className: String, funcPrefix: String) -> (value: [Model]?, error: String?) {
        
        var value : Any?
        
        do {
            value = try JSONSerialization.jsonObject(with: JSON.data(using: String.Encoding.utf8)!, options: JSONSerialization.ReadingOptions.mutableContainers)
            NSLog("\(value)")
        } catch {
            return (nil, "不是标准JSON格式")
        }
        if(value is NSMutableDictionary){
            guard let dict = value as? NSMutableDictionary else {
                return (nil, "JSON串是空的")
            }
            
            let models = JSONModel.matchingKeyAndType(values: dict)
            NSLog("\(models)")
            return (models, nil)
        }else if(value is NSMutableArray){
            //            guard let arr = value as? NSMutableArray else {
            //                return (-102, "JSON串是空的", nil)
            //            }
            return (nil, "暂不支持数组格式的JSON")
            
        }
        
        return (nil, "异常退出")
    }
    
    
    /// 匹配key与value的类型
    class func matchingKeyAndType(values: NSDictionary?) ->[Model]?{
        guard values != nil && values!.count > 0 else { return nil }
        
        var returnValue: [Model]? = []
        
        for key in values!.allKeys {
            let _key = key as! String
            let model = Model(_key, keyType.unknow, nil)
            if(JSONModel.isStirng(value: values![_key])){
                model.type = keyType.string
            }else if(JSONModel.isInteger(value: values![_key])){
                model.type = keyType.integer
            }else if(JSONModel.isFloat(value: values![_key])){
                model.type = keyType.float
            }else if(JSONModel.isBool(value: values![_key])){
                model.type = keyType.bool
            }else if(JSONModel.isArray(value: values![_key])){
                model.type = keyType.array
                model.subModel = JSONModel.mergeKeys(values: values![_key] as? [NSDictionary])
            }else if(JSONModel.isObject(value: values![_key])){
                model.type = keyType.object
                model.subModel = JSONModel.matchingKeyAndType(values: values![_key] as? NSDictionary)
            }
            
            returnValue?.append(model)
        }
        
        return returnValue
    }
    
    
    /// 统计数组元素中不同的key(暂时用处不大,还不能解决嵌套数组、字典的问题)
    class func mergeKeys(values: [NSDictionary]?) -> [Model]? {
        guard values != nil && values!.count > 0 else { return nil }
        
        let dic = NSMutableDictionary()
        var returnValue: [Model]? = []
        
        for item in values! {
            for key in item.allKeys {
                let model = Model(key as? String, keyType.unknow, nil)
                
                if(JSONModel.isStirng(value: item[key])){
                    model.type = keyType.string
                }else if(JSONModel.isInteger(value: item[key])){
                    model.type = keyType.integer
                }else if(JSONModel.isFloat(value: item[key])){
                    model.type = keyType.float
                }else if(JSONModel.isBool(value: item[key])){
                    model.type = keyType.bool
                }else if(JSONModel.isArray(value: item[key])){
                    model.type = keyType.array
                    model.subModel = JSONModel.mergeKeys(values: item[key] as? [NSDictionary])
                }else if(JSONModel.isObject(value: item[key])){
                    model.type = keyType.object
                    model.subModel = JSONModel.matchingKeyAndType(values: item[key] as? NSDictionary)
                }
                
                //确定是否已有该KEY,如有则替换不追加
                dic.setValue(model, forKey: key as! String)
            }
        }
        for key in dic.allKeys {
            returnValue?.append(Model(key as? String, (dic[key] as! Model).type, (dic[key] as! Model).subModel))
        }
        return returnValue
    }
    
    //MARK: - 类型判断
    
    ///验证是否为Null类型
    class func isNull(value: Any?) -> Bool{
        return value is NSNull
    }
    ///验证是否为Bool类型
    class func isBool(value: Any?) -> Bool {
        return (value is NSNumber) && !(value is CGFloat)
    }
    ///验证是否为Integer类型
    class func isInteger(value: Any?) -> Bool {
        guard (value is NSNumber)/*其实前面这个条件可以去掉*/ && (value is CGFloat) else { return false }
        return !(value as! NSNumber).stringValue.contains(".")
    }
    ///验证是否为Float类型
    class func isFloat(value: Any?) -> Bool {
        guard value is NSNumber else { return false }
        return (value as! NSNumber).stringValue.contains(".")
    }
    ///验证是否为String类型
    class func isStirng(value: Any?) -> Bool {
        return value is NSString
    }
    ///验证是否为key/value的无序集合
    class func isObject(value: Any?) -> Bool {
        return value is NSDictionary
    }
    ///验证是否为Array类型的有序的集合
    class func isArray(value: Any?) -> Bool {
        return value is NSArray
    }
    
    //MARK: - 转换成文件格式的字符串(Swift)
    //生成Swift头
    class func makeSwiftHead(_ modelCache: ModelCache) -> String {
        return "class \(modelCache.className): NSObject {\n\n"
    }
    //生成Swift属性
    class func makeSwiftVariable(_ modelCache: ModelCache) -> String {
        var returnValue: String = ""
        
        //统计最长属性名
        var varLength = 0
        for modelItdm in modelCache.models {
//            varLength = varLength > key.keyName!.utf16.count ?: key.keyName!.utf16.count
            if(modelItdm.name!.utf16.count > varLength){
                varLength = modelItdm.name!.utf16.count
            }
        }
        
        //生成属性字符串
        for modelItem in modelCache.models {
            //计算长度差
            var stringSpace = ""
            for _ in 0..<(varLength - modelItem.name!.utf16.count) {
                stringSpace.append(" ")
            }
            
            if(modelItem.type == .string){
                returnValue.append("\tvar \(modelItem.name!)\(stringSpace): String?\n")
            }else if(modelItem.type == .integer){
                returnValue.append("\tvar \(modelItem.name!)\(stringSpace): NSInteger = 0\n")
            }else if(modelItem.type == .float){
                returnValue.append("\tvar \(modelItem.name!)\(stringSpace): CGFloat = 0.0\n")
            }else if(modelItem.type == .bool){
                returnValue.append("\tvar \(modelItem.name!)\(stringSpace): Bool = false\n")
            }else if(modelItem.type == .array){
                returnValue.append("\tvar \(modelItem.name!)\(stringSpace): NSArray?\n")
            }else if(modelItem.type == .object){
                returnValue.append("\tvar \(modelItem.name!)\(stringSpace): NSDictionary?\n")
            }else{
                returnValue.append("\tvar \(modelItem.name!)\(stringSpace): Any?\n")
            }
        }
        
        return returnValue + "\n"
    }
    //生成Swift解析方法
    class func makeSwiftInstance(_ modelCache: ModelCache) -> String {
        //头
        var returnString = "\tclass func \(modelCache.funcPrefix)(JSON: NSDictionary?) -> \(modelCache.className) {\n"
        //过程
        returnString.append("\t\tlet instance = \(className)()\n\n")
        
        for modelItem in modelCache.models {
            if(modelItem.type == .string){
                returnString.append("\t\tinstance.\(modelItem.name!) = JSON?.value(forKey: \"\(modelItem.name!)\") as? String\n")
            }else if(modelItem.type == .integer){
                returnString.append("\t\tinstance.\(modelItem.name!) = JSON?.value(forKey: \"\(modelItem.name!)\") as! NSInteger\n")
            }else if(modelItem.type == .float){
                returnString.append("\t\tinstance.\(modelItem.name!) = JSON?.value(forKey: \"\(modelItem.name!)\") as! CGFloat\n")
            }else if(modelItem.type == .bool){
                returnString.append("\t\tinstance.\(modelItem.name!) = JSON?.value(forKey: \"\(modelItem.name!)\") as! Bool\n")
            }else if(modelItem.type == .array){
                returnString.append("\t\tinstance.\(modelItem.name!) = JSON?.value(forKey: \"\(modelItem.name!)\") as? NSArray\n")
            }else if(modelItem.type == .object){
                returnString.append("\t\tinstance.\(modelItem.name!) = JSON?.value(forKey: \"\(modelItem.name!)\") as? NSDictionary\n")
            }else{
                returnString.append("\t\tinstance.\(modelItem.name!) = JSON?.value(forKey: \"\(modelItem.name!)\")\n")
            }
        }
        
        returnString.append("\n\t\treturn instance\n")
        
        //尾
        returnString.append("\t}\n")
        return returnString
    }
    //生成Swift结尾
    class func makeSwiftTail() -> String {
        return "}"
    }
    
    //MARK: - 转换成文件格式的字符串(OC)
    //OC.h头
    class func makeOCHHead(_ modelCache: ModelCache) -> String {
        return "#import <Foundation/Foundation.h>\n\n@interface \(modelCache.className) : NSObject\n"
    }
    //OC.h属性
    class func makeOCHVariable(_ modelCache: ModelCache) -> String {
        var returnValue: String = "\n"
        //生成属性字符串
        for modelItem in modelCache.models {
            if(modelItem.type == .string){
                returnValue.append("@property (nonatomic, copy)   NSString     *\(modelItem.name!);\n")
            }else if(modelItem.type == .integer){
                returnValue.append("@property (nonatomic, assign) NSInteger    \(modelItem.name!);\n")
            }else if(modelItem.type == .float){
                returnValue.append("@property (nonatomic, assign) CGFloat      \(modelItem.name!);\n")
            }else if(modelItem.type == .bool){
                returnValue.append("@property (nonatomic, assign) BOOL         \(modelItem.name!);\n")
            }else if(modelItem.type == .array){
                returnValue.append("@property (nonatomic, copy)   NSArray      *\(modelItem.name!);\n")
            }else if(modelItem.type == .object){
                returnValue.append("@property (nonatomic, copy)   NSDictionary *\(modelItem.name!);\n")
            }else{
                returnValue.append("@property (nonatomic, strong) id \(modelItem.name!);\n")
            }
        }
        return returnValue
    }
    //OC.h解析方法
    class func makeOCHInstance(_ modelCache: ModelCache) -> String {
        return "\n+ (\(modelCache.className) *)\(modelCache.funcPrefix): (id)JSON;\n"
    }
    //OC.h尾
    class func makeOCHTail() -> String {
        return "\n@end"
    }
    
    //OC.m头
    class func makeOCMHead(_ modelCache: ModelCache, fileName: String) -> String {
        return "#import \"\(fileName)\"\n\n@implementation \(modelCache.className)\n"
    }
    //OC.m解析方法
    class func makeOCMInstance(_ modelCache: ModelCache) -> String {
        var returnValue = "\n+ (\(modelCache.className) *)\(modelCache.funcPrefix): (id) JSON {\n"
        returnValue.append("\t\(modelCache.className) *instance = [[\(modelCache.className) alloc] init];\n\n")
        
        for modelItem in modelCache.models {
            if(modelItem.type == .string){
                returnValue.append("\tinstance.\(modelItem.name!) = JSON[@\"\(modelItem.name!)\"];\n")
            }else if(modelItem.type == .integer){
                returnValue.append("\tinstance.\(modelItem.name!) = [JSON[@\"\(modelItem.name!)\"] integerValue];\n")
            }else if(modelItem.type == .float){
                returnValue.append("\tinstance.\(modelItem.name!) = [JSON[@\"\(modelItem.name!)\"] floatValue];\n")
            }else if(modelItem.type == .bool){
                returnValue.append("\tinstance.\(modelItem.name!) = [JSON[@\"\(modelItem.name!)\"] boolValue];\n")
            }else if(modelItem.type == .array){
                returnValue.append("\tinstance.\(modelItem.name!) = JSON[@\"\(modelItem.name!)\"];\n")
            }else if(modelItem.type == .object){
                returnValue.append("\tinstance.\(modelItem.name!) = JSON[@\"\(modelItem.name!)\"];\n")
            }else{
                returnValue.append("\tinstance.\(modelItem.name!) = JSON[@\"\(modelItem.name!)\"];\n")
            }
        }
        
        returnValue.append("\n\treturn instance;\n}")
        return returnValue
    }
    //OC.m尾
    class func makeOCMTail() -> String {
        return "\n@end"
    }
}
