//
//  ViewController.m
//  AutoPackageTool
//
//  Created by Tang杰 on 2018/11/16.
//  Copyright © 2018年 Tang杰. All rights reserved.
//

#import "ViewController.h"
#import <AFNetworking.h>

@interface ViewController ()
{
    NSTask *_task;
}
@property (nonatomic, assign) BOOL isWorkspace;

/** 项目路径 */
@property (weak) IBOutlet NSTextField *projectPath;
/** 工程名称 */
@property (weak) IBOutlet NSTextField *projectName;
@property (weak) IBOutlet NSTextField *schemeName;
@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSPopUpButton *popUpButton;
/** 测试平台 */
@property (weak) IBOutlet NSPopUpButton *testPlatform;
/** 蒲公英APIKey */
@property (weak) IBOutlet NSTextField *pgyerAPIKey;
/** fir api_token */
@property (weak) IBOutlet NSTextField *firToken;

@property (unsafe_unretained) IBOutlet NSTextView *textView;

@property (nonatomic, copy) NSString *archivePath;
@end

@implementation ViewController
- (void)dataCache {
    NSMutableDictionary *dic = @{}.mutableCopy;
    [dic setObject:self.projectPath.stringValue ? : @"" forKey:@"projectPath"];
    [dic setObject:self.projectName.stringValue ? : @"" forKey:@"projectName"];
    [dic setObject:self.schemeName.stringValue ? : @"" forKey:@"schemeName"];
    [dic setObject:self.popUpButton.titleOfSelectedItem ? : [self.popUpButton itemTitleAtIndex:0] forKey:@"method"];
    [dic setObject:self.testPlatform.titleOfSelectedItem ? : [self.testPlatform itemTitleAtIndex:0] forKey:@"testPlatform"];
    [dic setObject:self.pgyerAPIKey.stringValue ? : @"" forKey:@"pgyerAPIKey"];
    [dic setObject:self.firToken.stringValue ? : @"" forKey:@"firToken"];
    [[NSUserDefaults standardUserDefaults] setObject:dic forKey:@"dataCache"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)readCacheData {
    NSMutableDictionary *dic = [[NSUserDefaults standardUserDefaults] objectForKey:@"dataCache"];
    if (!dic) return;
    self.projectPath.stringValue = [dic objectForKey:@"projectPath"];
    self.projectName.stringValue = [dic objectForKey:@"projectName"];
    self.schemeName.stringValue = [dic objectForKey:@"schemeName"];
    [self.popUpButton selectItemWithTitle:[dic objectForKey:@"method"]];
    [self.testPlatform selectItemWithTitle:[dic objectForKey:@"testPlatform"]];
    self.pgyerAPIKey.stringValue = [dic objectForKey:@"pgyerAPIKey"];
    self.firToken.stringValue = [dic objectForKey:@"firToken"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self readCacheData];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:self.projectPath];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataCache) name:NSApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileHandleReadCompletionNotification:) name:NSFileHandleReadCompletionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileHandleReadCompletion:) name:NSFileHandleReadToEndOfFileCompletionNotification object:nil];
}
- (void)textDidChange:(NSNotification *)notification {
    if ([notification.object isEqual:self.projectPath]) {
        [self projectPathDidChange];
    }
}
- (void)projectPathDidChange {
    if ([self.projectPath.stringValue.pathExtension isEqualToString:@"xcodeproj"] ||
        [self.projectPath.stringValue.pathExtension isEqualToString:@"xcworkspace"]) {
        self.projectName.stringValue = self.projectPath.stringValue.lastPathComponent.stringByDeletingPathExtension;
        self.schemeName.stringValue = self.projectName.stringValue;
        self.projectPath.stringValue = [self.projectPath.stringValue stringByDeletingLastPathComponent];
    }
}

- (IBAction)selectpProjectPath:(NSButton *)sender {
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    openPanel.canChooseFiles = true;
    openPanel.canChooseDirectories = true;
    openPanel.allowsMultipleSelection = false;
    openPanel.allowsOtherFileTypes = false;
    openPanel.allowedFileTypes = @[@"xcodeproj", @"xcworkspace"];
    if ([openPanel runModal] == NSModalResponseOK) {
        NSString *path = [openPanel.URLs.firstObject path];
        self.projectPath.stringValue = path;
        [self projectPathDidChange];
    }
}
- (NSString *)exportPath {
    NSString *exportPath = [self.projectPath.stringValue stringByAppendingPathComponent:@"package"];
    return exportPath;
}
- (NSString *)ipaPath {
    NSString *ipaPath = [self.exportPath stringByAppendingPathComponent:self.schemeName.stringValue];
    return [ipaPath stringByAppendingPathExtension:@"ipa"];
}
- (NSDictionary *)infoDictionary {
    NSString *infoPath = [self.exportPath stringByAppendingPathComponent:@"Info"];
    infoPath = [infoPath stringByAppendingPathExtension:@"plist"];
    return [NSDictionary dictionaryWithContentsOfFile:infoPath];
}
- (NSString *)bundleId {
    return [self.infoDictionary objectForKey:@"CFBundleIdentifier"];
}


- (IBAction)clickStartButton:(NSButton *)sender {
    if (![self checkProjectPath]) return;
    sender.enabled = NO;
    
    [self configArchivePath];
    [[self xcodeBuildProject] setTerminationHandler:^(NSTask * task) {
        if (task.terminationStatus == 0) {
            [[self exportIpa] setTerminationHandler:^(NSTask * task) {
                if (task.terminationStatus == 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self uploadToTesPlatform];
                    });
                } else {
                    [self updateTextViewByText:@"导出失败！！！"];
                }
            }];
        } else {
            [self updateTextViewByText:@"构建失败！！！"];
        }
    }];
}
/** 检查项目路径 */
- (BOOL)checkProjectPath {
    NSString *xcworkspacePath = [[self.projectPath.stringValue stringByAppendingPathComponent:self.projectName.stringValue] stringByAppendingPathExtension:@"xcworkspace"];
    NSString *xcodeprojPath = [[self.projectPath.stringValue stringByAppendingPathComponent:self.projectName.stringValue] stringByAppendingPathExtension:@"xcodeproj"];
    self.isWorkspace = [[NSFileManager defaultManager] fileExistsAtPath:xcworkspacePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:xcodeprojPath] && !self.isWorkspace) {
        [self showAlertWithTitle:@"温馨提示" message:@"请选择正确的project Path"];
        return NO;
    }
    return YES;
}

/** 配置 archivePath*/
- (void)configArchivePath {
    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSString *archivePath = [NSString stringWithFormat:@"%@/Developer/Xcode/Archives/%@",NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject, [dateFormatter stringFromDate:date]];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:archivePath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:archivePath withIntermediateDirectories:YES attributes:nil error:&error];
    }
    archivePath = [archivePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.xcarchive", self.schemeName.stringValue, [dateFormatter stringFromDate:date]]];
    self.archivePath = archivePath;
}
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    NSAlert * alert = [[NSAlert alloc]init];
    alert.messageText = title;
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"确定"];
    [alert setInformativeText:message];
    [alert beginSheetModalForWindow:[self.view window] completionHandler:^(NSModalResponse returnCode) {
        
    }];
}

/** 编译项目 */
- (NSTask *)xcodeBuildProject
{
    if (self.schemeName.stringValue.length == 0) {
        [self showAlertWithTitle:@"温馨提示" message:@"请选择正确的project Path"];
        return nil;
    } else if (self.projectName.stringValue.length == 0) {
        [self showAlertWithTitle:@"温馨提示" message:@"请选择正确的project Path"];
        return nil;
    }
    [self updateTextViewByText:@"开始构建。。。"];
    //切到项目目录
    NSString *cd = [NSString stringWithFormat:@"cd %@",self.projectPath.stringValue];
    // 1.清理工程
    NSString *clean = nil;
    // 2.编译项目
    NSString *build = nil;
    if (self.isWorkspace) {
        clean = [NSString stringWithFormat:@"/usr/bin/xcodebuild -workspace %@.xcworkspace -scheme %@ clean",self.projectName.stringValue,self.schemeName.stringValue];
        build = [NSString stringWithFormat:@"/usr/bin/xcodebuild archive\
                 -workspace %@.xcworkspace\
                 -scheme %@ \
                 -archivePath %@" ,self.projectName.stringValue,self.schemeName.stringValue,self.archivePath];
    } else {
        clean = [NSString stringWithFormat:@"/usr/bin/xcodebuild -project %@.xcodeproj -scheme %@ clean",self.projectName.stringValue,self.schemeName.stringValue];
        build = [NSString stringWithFormat:@"/usr/bin/xcodebuild archive\
                 -project %@.xcodeproj\
                 -scheme %@ \
                 -archivePath %@" ,self.projectName.stringValue,self.schemeName.stringValue,self.archivePath];
    }
    
    NSString *shell1 = [NSString stringWithFormat:@"%@\n %@\n %@\n",cd,clean,build];
    
    return [self runSystemCommand:shell1];
}
/** 导出ipa */
- (NSTask *)exportIpa {
    [self updateTextViewByText:@"导出ipa。。。"];
    NSString *exportPath = [self.projectPath.stringValue stringByAppendingPathComponent:@"package"];
    NSString *exportOptionsPlist = [self.projectPath.stringValue stringByAppendingPathComponent:@"ExportOptions.plist"];
    // 先删除export_options_plist文件
    if ([[NSFileManager defaultManager] fileExistsAtPath:exportOptionsPlist]) {
        [[NSFileManager defaultManager] removeItemAtPath:exportOptionsPlist error:nil];
    }
    // 根据参数生成export_options_plist文件
    NSString *configPlist = [NSString stringWithFormat:@"/usr/libexec/PlistBuddy -c 'Add :method String %@' %@",self.popUpButton.selectedItem.title, exportOptionsPlist];
    // 3.输出包
    NSString *exportArchive = [NSString stringWithFormat:@"/usr/bin/xcodebuild \
                               -exportArchive \
                               -archivePath %@ \
                               -exportPath %@ \
                               -exportOptionsPlist %@ \
                               -allowProvisioningUpdates",self.archivePath, exportPath,exportOptionsPlist];
    return [self runSystemCommand:[NSString stringWithFormat:@"%@ \n%@",configPlist, exportArchive]];
}
/** 上传到测试平台 */
- (void)uploadToTesPlatform {
    if (self.testPlatform.indexOfSelectedItem == 1) {
        [[self uploadToFir] setTerminationHandler:^(NSTask * task) {
            if (task.terminationStatus != 0) {
                [self updateTextViewByText:@"==========上传fir失败=========="];
            }
        }];;
    } else if (self.testPlatform.indexOfSelectedItem == 2) {
        [[self uploadToPgyer] setTerminationHandler:^(NSTask * task) {
            if (task.terminationStatus != 0) {
                [self updateTextViewByText:@"==========上传蒲公英失败=========="];
            }
        }];
    } else if (self.testPlatform.indexOfSelectedItem == 3) {
        [[self uploadToFir] setTerminationHandler:^(NSTask * task) {
            if (task.terminationStatus != 0) {
                [self updateTextViewByText:@"==========上传fir失败=========="];
            }
            [[self uploadToPgyer] setTerminationHandler:^(NSTask * task) {
                if (task.terminationStatus != 0) {
                    [self updateTextViewByText:@"==========上传蒲公英失败=========="];
                }
            }];
        }];
    }
}

/** 上传到蒲公英 */
- (NSTask *)uploadToPgyer {
    [self updateTextViewByText:@"上传到蒲公英。。。"];
    NSString *uploadToPgyer = [NSString stringWithFormat:@"curl -F 'file=@%@'\
                                   -F '_api_key=%@' https://www.pgyer.com/apiv2/app/upload",self.ipaPath,self.pgyerAPIKey.stringValue];
    return [self runSystemCommand:uploadToPgyer];
}
/** 上传到fir */
- (NSTask *)uploadToFir {
    [self updateTextViewByText:@"上传到fir。。。"];
    NSString *uploadToFir = [NSString stringWithFormat:@"fir p %@ -T %@",self.ipaPath,self.firToken.stringValue];
    return [self runSystemCommand:uploadToFir];
}


- (NSTask *)runSystemCommand:(NSString *)cmd
{
    NSLog(@"命令------->%@",cmd);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.startButton.enabled = NO;
    });
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:@[@"-c", cmd]];
    NSPipe *outputPipe = [[NSPipe alloc] init];
    NSPipe *errorPipe = [[NSPipe alloc] init];
    [task setStandardOutput:outputPipe];
    [task setStandardError:errorPipe];
    NSFileHandle *fileHandle = [outputPipe fileHandleForReading];
    [fileHandle readInBackgroundAndNotify];
    [[errorPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    [task launch];
    _task = task;
    
    return _task;
}
- (void)fileHandleReadCompletion:(NSNotification *)not {
    NSData * data = [not.userInfo valueForKey:NSFileHandleNotificationDataItem];
    NSData * data1 = [not.userInfo valueForKey:NSFileHandleNotificationFileHandleItem];
    NSLog(@"%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    NSLog(@"%@",[[NSString alloc] initWithData:data1 encoding:NSUTF8StringEncoding]);
}

- (void)fileHandleReadCompletionNotification:(NSNotification *)not {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSData * data = [not.userInfo valueForKey:NSFileHandleNotificationDataItem];
        NSObject *ob = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        if (!ob) {
            ob = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        [self updateTextViewByText:ob.description];
        if (data.length || self->_task.isRunning) {
            [not.object readInBackgroundAndNotify];
        } else if (!self->_task.isRunning) {
            self.startButton.enabled = YES;
        }
    });
}

- (void)updateTextViewByText:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSScrollView *scrollView = [self.textView enclosingScrollView];
        bool scrollToEnd = [self.textView visibleRect].origin.y == CGRectGetHeight(self.textView.frame) - CGRectGetHeight(scrollView.frame);
        self.textView.string = [self.textView.string stringByAppendingFormat:@"\n%@",text];
        if (scrollToEnd) {
            [self.textView scrollRangeToVisible:NSMakeRange(self.textView.string.length, 1)];
        }
        NSLog(@"输出结果--------->%@",text);
    });
}

- (AFHTTPSessionManager *)sessionManager {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [[AFJSONRequestSerializer alloc] init];
    manager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
    manager.requestSerializer.stringEncoding = NSUTF8StringEncoding;
    // 解决AFN反序列化时的问题
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html",nil];
    return manager;
}

@end
