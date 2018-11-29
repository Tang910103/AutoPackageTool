//
//  ViewController.m
//  AutoPackageTool
//
//  Created by Tang杰 on 2018/11/16.
//  Copyright © 2018年 Tang杰. All rights reserved.
//

#import "ViewController.h"
#import <AFNetworking.h>
#import "CustomView.h"

#define weakObj(self) __weak typeof(self) weak_##self = self;
#define strongObj(self) __strong typeof(self) strong_##self = self;

@interface ViewController ()
{
    NSTask *_task;
}
@property (nonatomic, assign) BOOL isWorkspace;

/** 项目路径 */
@property (weak) IBOutlet NSTextField *projectPath;
/** ipa导出路径 */
@property (weak) IBOutlet NSTextField *exportPath;
/** 工程名称 */
@property (weak) IBOutlet NSTextField *projectName;
@property (weak) IBOutlet NSTextField *schemeName;
@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSButton *stopButton;
@property (weak) IBOutlet NSPopUpButton *popUpButton;
/** 测试平台 */
@property (weak) IBOutlet NSPopUpButton *testPlatform;
/** 蒲公英APIKey */
@property (weak) IBOutlet NSTextField *pgyerAPIKey;
/** fir api_token */
@property (weak) IBOutlet NSTextField *firToken;

@property (unsafe_unretained) IBOutlet NSTextView *textView;
@property (weak) IBOutlet NSView *contentView;
@property (nonatomic, strong) CustomView *maskView;

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
- (void)viewWillLayout
{
    [super viewWillLayout];
    self.maskView.frame = self.contentView.bounds;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.exportPath.stringValue = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES).firstObject;

    self.maskView = [[CustomView alloc] init];
    [self.contentView addSubview:self.maskView];
    [self.maskView setHidden:YES];

    [self readCacheData];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:self.projectPath];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataCache) name:NSApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileHandleReadCompletionNotification:) name:NSFileHandleReadCompletionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileHandleReadCompletion:) name:NSFileHandleReadToEndOfFileCompletionNotification object:nil];
    [self.startButton addObserver:self forKeyPath:@"enabled" options:NSKeyValueObservingOptionNew context:nil];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([object isEqual:self.startButton]) {
        self.stopButton.enabled = !self.startButton.enabled;
    }
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
- (IBAction)selectpExportPath:(NSButton *)sender {
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    openPanel.canChooseFiles = false;
    openPanel.canChooseDirectories = true;
    openPanel.allowsMultipleSelection = false;
    openPanel.allowsOtherFileTypes = false;
    if ([openPanel runModal] == NSModalResponseOK) {
        NSString *path = [openPanel.URLs.firstObject path];
        self.exportPath.stringValue = path;
    }
}
- (NSString *)ipaPath {
    NSString *ipaPath = [[self.exportPath.stringValue stringByAppendingPathComponent:self.schemeName.stringValue] stringByAppendingPathComponent:self.schemeName.stringValue];
    return [ipaPath stringByAppendingPathExtension:@"ipa"];
}
- (NSDictionary *)infoDictionary {
    NSString *infoPath = [self.projectPath.stringValue stringByAppendingPathComponent:@"Info"];
    infoPath = [infoPath stringByAppendingPathExtension:@"plist"];
    return [NSDictionary dictionaryWithContentsOfFile:infoPath];
}
- (NSString *)bundleId {
    return [self.infoDictionary objectForKey:@"CFBundleIdentifier"];
}
- (IBAction)clickStopButton:(NSButton *)sender {
    weakObj(self)
    [_task setTerminationHandler:^(NSTask * task) {
        [weak_self updateTextViewByText:@"已停止！！！"];
    }];
    [_task terminate];
}


- (IBAction)clickStartButton:(NSButton *)sender {
    if (![self checkPath]) return;
//    取消任意输入框的输入状态
    [[NSApplication sharedApplication].mainWindow makeFirstResponder:self];
    sender.enabled = NO;
    [self.maskView setHidden:NO];
    self.textView.string = @"";
    [self configArchivePath];
    [[self xcodeBuildProject] setTerminationHandler:^(NSTask * task) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (task.terminationStatus == 0) {
                [self exportIpa];
            } else {
                [self updateTextViewByText:@"构建失败！！！"];
            }
        });
    }];
}
/** 检查路径 */
- (BOOL)checkPath {
    if (self.schemeName.stringValue.length == 0) {
        [self showAlertWithTitle:@"温馨提示" message:@"请输入scheme Name"];
        return NO;
    } else if (self.projectName.stringValue.length == 0) {
        [self showAlertWithTitle:@"温馨提示" message:@"请输入project Name"];
        return NO;
    } else if (self.exportPath.stringValue.length == 0) {
        [self showAlertWithTitle:@"温馨提示" message:@"请选择export Path"];
        return NO;
    }
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
- (void)exportIpa {
    [self updateTextViewByText:@"导出ipa。。。"];
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
                               -allowProvisioningUpdates",self.archivePath, [self.exportPath.stringValue stringByAppendingPathComponent:self.schemeName.stringValue],exportOptionsPlist];
    [[self runSystemCommand:[NSString stringWithFormat:@"%@ \n%@",configPlist, exportArchive]]setTerminationHandler:^(NSTask * task) {
        // 删除临时export_options_plist文件
        if ([[NSFileManager defaultManager] fileExistsAtPath:exportOptionsPlist]) {
            [[NSFileManager defaultManager] removeItemAtPath:exportOptionsPlist error:nil];
        }
        if (task.terminationStatus == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self uploadToTesPlatform];
            });
        } else {
            [self updateTextViewByText:@"导出失败！！！"];
        }
    }];
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
    NSString *uploadToFir = [NSString stringWithFormat:@"fir p %@ -T %@ -c'%@'",self.ipaPath,self.firToken.stringValue,@"无"];
    return [self runSystemCommand:uploadToFir];
}


- (NSTask *)runSystemCommand:(NSString *)cmd
{
    NSLog(@"命令------->%@",cmd);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.maskView setHidden:NO];
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
        [self.maskView setHidden:YES];
        [self->_task terminate];
        self->_task = nil;
    }
}

- (void)updateTextViewByText:(NSString *)text {
    if (text.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.textView.layoutManager.allowsNonContiguousLayout = NO;
        NSScrollView *scrollView = [self.textView enclosingScrollView];
        bool scrollToEnd = [self.textView visibleRect].origin.y == CGRectGetHeight(self.textView.frame) - CGRectGetHeight(scrollView.frame);
        [[[self.textView textStorage] mutableString] appendString:[NSString stringWithFormat:@"\n%@",text]];
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
