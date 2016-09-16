//
//  ViewController.m
//  RePriority
//
//  Created by Sunhy on 16/9/12.
//  Copyright © 2016年 Sunhy. All rights reserved.
//

#import "ViewController.h"
#import "CusStyle.h"
#import "FMDB.h"

static NSString * const regularExp = @"\"drawpriority\": \\d+";
static NSString * const keyWords = @"\"drawpriority\": ";
@interface ViewController ()  <NSTabViewDelegate, NSTableViewDataSource, NSTextFieldDelegate>

@property (nonatomic, strong) NSMutableArray *myDataSourceArray;

@property (nonatomic, weak) IBOutlet NSTableView *cusTableView;
@property (weak) IBOutlet NSTextField *infoLabel;
@property (weak) IBOutlet NSTextField *drawPriorityOffsetTextField;
@property (weak) IBOutlet NSButton *batchBtn;

/** 批量操作时的其实偏移*/
@property (nonatomic, assign) int drawPriorityOffset;

@property (nonatomic, strong) NSURL *dbFilePath;

@end

/** 本工具还有缺陷，可能一个style有两个drawpriority*/
@implementation ViewController

/** 指定了setter和getter，必须指定@synthesize*/
@synthesize myDataSourceArray = _myDataSourceArray;

- (void)viewDidLoad {
    if (!self.dbFilePath) {
        self.batchBtn.enabled = NO;
        self.drawPriorityOffsetTextField.enabled = NO;
    }
    
    [super viewDidLoad];
    [self.infoLabel setSelectable:YES];
    self.cusTableView.dataSource = self;
    self.cusTableView.delegate = self;
}

- (void)viewWillAppear {
    [super viewWillAppear];
    if (self.dbFilePath) {
        self.infoLabel.stringValue = [_dbFilePath absoluteString];
    } else {
        self.infoLabel.stringValue = @"请选择数据库文件";
    }
}

#pragma mark - **************** getter setter
- (NSMutableArray *)myDataSourceArray {
    if (!_myDataSourceArray) _myDataSourceArray = [NSMutableArray array];
    return _myDataSourceArray;
}

- (void)setMyDataSourceArray:(NSMutableArray *)myDataSourceArray {
    _myDataSourceArray = myDataSourceArray;
    [self.cusTableView reloadData];
}

- (void)setDrawPriorityOffset:(int)drawPriorityOffset {
    _drawPriorityOffset = drawPriorityOffset;
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.myDataSourceArray.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    CusStyle *style = self.myDataSourceArray[row];
    NSString *text;
    NSString *cellIdentifier;
    NSTableCellView *cell;
    if (tableColumn == tableView.tableColumns[0]) {
        text = style.styleName;
        cellIdentifier = @"NameCellID";
        cell = [tableView makeViewWithIdentifier:cellIdentifier owner:nil];
       [cell.textField setEditable:NO];
    } else if (tableColumn == tableView.tableColumns[1]) {
        text = style.style;
        cellIdentifier = @"StyleCellID";
        
        BOOL flag = NO;
        NSString *tempStr = [self fetchDrawPriority:text mutilFlag:&flag];
        if (tempStr) {
            text = tempStr;
        } else {
            text = @"----";
        }
        cell = [tableView makeViewWithIdentifier:cellIdentifier owner:nil];
        [cell.textField setEditable:YES];
        cell.textField.delegate = self;
        if (flag){
            cell.wantsLayer = YES;  // make the cell layer-backed
            cell.layer.backgroundColor = [[NSColor redColor] CGColor];
        }
    }
    
    
    cell.textField.stringValue = text;
    return cell;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return YES;
}

- (BOOL)selectionShouldChangeInTableView:(NSTableView *)tableView {
    return YES;
}

/** 从text获取要显示的信息*/
- (NSString *)fetchDrawPriority:(NSString *)text mutilFlag:(BOOL *)flag{
    //是否有多个pri
    NSMutableString *string = [NSMutableString stringWithString:text];
    NSRange range = [string rangeOfString:regularExp options:NSRegularExpressionSearch];
    NSString *str;
    if (range.length > 0) {
        str = [string substringWithRange:range];
        NSString *tempS = [text substringFromIndex:range.location + range.length];
        NSRange rangTemp = [tempS rangeOfString:regularExp options:NSRegularExpressionSearch];
        if (rangTemp.length > 0) {
            *flag = YES;
        }
    }
    return str;
}

- (NSString *)construcPriorityStr:(int)drawPriortiy {
    return [NSString stringWithFormat:@"%@%d", keyWords, drawPriortiy];
}

/** 选择btn响应事件*/
- (IBAction)chooseSourceBtnAction:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    // display the panel
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            // grab a reference to what has been selected
            self.dbFilePath = [[panel URLs]objectAtIndex:0];
            if (self.dbFilePath) {
                NSString *path = [self.dbFilePath absoluteString];
                if (path) {
                    self.infoLabel.stringValue = path;
                    NSMutableArray *arrayTemp = [self fetchPriorityWithPath:path];
                    self.myDataSourceArray = arrayTemp;
                }
            } else {
                NSLog(@"error");
            }
        }
    }];
}


- (IBAction)saveBtnAction:(id)sender {
    
}

/** textfield文本编辑完成*/
- (void)controlTextDidEndEditing:(NSNotification *)obj
{
    NSTextField *textField = obj.object;
    NSString *replaceString = textField.stringValue;
    NSRange range = [replaceString rangeOfString:regularExp options:NSRegularExpressionSearch];
    if (range.length > 0) {
        CusStyle *styleTemp = self.myDataSourceArray[self.cusTableView.selectedRow];
        NSRange drawPriorityRange = [styleTemp.style rangeOfString:regularExp options:NSRegularExpressionSearch];
        NSRange leftStrRange = NSMakeRange(0, drawPriorityRange.location);
        NSRange rightStrRange = NSMakeRange(drawPriorityRange.location + drawPriorityRange.length, styleTemp.style.length - (drawPriorityRange.location + drawPriorityRange.length));
        NSString *newStr = [NSString stringWithFormat:@"%@%@%@", [styleTemp.style substringWithRange:leftStrRange], replaceString, [styleTemp.style substringWithRange:rightStrRange]];
        //写入数据库
        [self updatedb:self.dbFilePath styleName:styleTemp.styleName style:newStr];
    }
}

#pragma mark - **************** 数据库操作
- (NSMutableArray *)fetchPriorityWithPath:(NSString *)path {
    NSMutableArray *array = [NSMutableArray array];
    NSString *defaultDBPath = path;
    FMDatabase* db = [FMDatabase databaseWithPath:defaultDBPath];
    if(![db open])
    {
#ifdef DEBUG
        NSLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
#endif
    }
    // 搜索索引id
    NSString *sql = @"SELECT * FROM styles";
    FMResultSet *rs = [db executeQuery:sql];
    while ([rs next]) {
        CusStyle *style = [[CusStyle alloc] init];
        style.styleName =  [rs stringForColumn:@"name"];
        style.style = [rs stringForColumn:@"style"];
        [array addObject:style];
    }
    [rs close];
    [db close];
    return array;
}

/**
 *  更新数据库
 *
 *  @param path      数据库路径
 *  @param styleName name
 *  @param style     style
 */
- (void)updatedb:(NSURL *)path styleName:(NSString *)styleName style:(NSString *)style {
    NSString *defaultDBPath = [path absoluteString];
    FMDatabase* db = [FMDatabase databaseWithPath:defaultDBPath];
    if(![db open])
    {
#ifdef DEBUG
        NSLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
#endif
    }
    NSString *sql = [NSString stringWithFormat:@"update styles set style='%@' WHERE name='%@'", style, styleName];
    if (![db executeUpdate:sql]) {
        NSLog(@"update fail");
    }
    [db close];
}

- (void)copy:(id)sender;
{
    NSBeep();
}

- (NSString *)detailText {
    return @"fsdf";
}

/** 批量更新数据库*/
- (IBAction)batchBtnAction:(NSButton *)sender {
    int priorityOffset = [self.drawPriorityOffsetTextField intValue];
    self.drawPriorityOffset = priorityOffset;
    // 直接写入数据库
    for (int i=0; i<self.myDataSourceArray.count; i++) {
        CusStyle *styleTemp = self.myDataSourceArray[i];
        NSRange drawPriorityRange = [styleTemp.style rangeOfString:regularExp options:NSRegularExpressionSearch];
        NSRange leftStrRange = NSMakeRange(0, drawPriorityRange.location);
        NSRange rightStrRange = NSMakeRange(drawPriorityRange.location + drawPriorityRange.length, styleTemp.style.length - (drawPriorityRange.location + drawPriorityRange.length));
        NSString *newStr = [NSString stringWithFormat:@"%@%@%@", [styleTemp.style substringWithRange:leftStrRange], [self construcPriorityStr:_drawPriorityOffset++], [styleTemp.style substringWithRange:rightStrRange]];
        //写入数据库
        [self updatedb:self.dbFilePath styleName:styleTemp.styleName style:newStr];

    }
    // 更新视图
    if (self.dbFilePath) {
        self.myDataSourceArray = [self fetchPriorityWithPath:[self.dbFilePath absoluteString]];
        self.batchBtn.enabled = YES;
        self.drawPriorityOffsetTextField.enabled = YES;
    }
}

@end
