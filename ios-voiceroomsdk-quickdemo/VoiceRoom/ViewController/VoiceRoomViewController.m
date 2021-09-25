//
//  VoiceRoomViewController.m
//  ios-voiceroomsdk-quickdemo
//
//  Created by 叶孤城 on 2021/9/10.
//

#import "VoiceRoomViewController.h"
#import <RCVoiceRoomLib/RCVoiceRoomLib.h>
#import <SVProgressHUD.h>
#import "SeatInfoCollectionViewCell.h"
#import "UIColor+Hex.h"
#import <Masonry.h>
#import "UserManager.h"

static NSString * const cellIdentifier = @"SeatInfoCollectionViewCell";
@interface VoiceRoomViewController ()<UICollectionViewDataSource, UICollectionViewDelegate, RCVoiceRoomDelegate>

@property (nonatomic, copy) NSString *roomId;
@property (nonatomic, assign) BOOL isCreate;

// 根据roomInfoDidUpdate获取的最新roomInfo
@property (nonatomic, copy) RCVoiceRoomInfo *roomInfo;
// 根据seatInfoDidUpdate 获取的最新麦位信息
@property (nonatomic, copy) NSArray<RCVoiceSeatInfo *> *seatlist;
// 用来显示麦位的collectionView
@property (nonatomic, strong) UICollectionView *collectionView;
// 背景
@property (nonatomic, strong) UIImageView *backgroundImageView;
// 退出房间
@property (nonatomic, strong) UIButton *quitButton;
// 用户id label
@property (nonatomic, strong) UILabel *userLabel;
@end

@implementation VoiceRoomViewController

- (instancetype)initWithJoinRoomId:(NSString *)roomId {
    if (self = [super initWithNibName:nil bundle:nil]) {
        self.roomId = roomId;
        self.isCreate = NO;
    }
    return self;
}

- (instancetype)initWithRoomId:(NSString *)roomId roomInfo:(RCVoiceRoomInfo *)roomInfo {
    if (self = [super initWithNibName:nil bundle:nil]) {
        self.roomId = roomId;
        self.roomInfo = roomInfo;
        self.isCreate = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [RCVoiceRoomEngine.sharedInstance setDelegate:self];
    if (self.isCreate) {
        [self createVoiceRoom:_roomId info:_roomInfo];
    } else {
        [self joinVoiceRoom:_roomId];
    }
    // 设置语聊房代理
    [self buildLayout];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

#pragma mark - Private Method

- (void)buildLayout {
    self.title = @"语聊房";
    self.view.backgroundColor = [UIColor colorFromHexString:@"#F6F8F9"];
    [self.view addSubview:self.backgroundImageView];
    [self.backgroundImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.view addSubview:self.quitButton];
    [self.quitButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.view).inset(20);
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(20);
        make.size.equalTo(@(CGSizeMake(44, 44)));
    }];
    
    self.userLabel.text = [NSString stringWithFormat:@"当前用户id：%@", [UserManager sharedManager].currentUser.userId];
    [self.view addSubview:self.userLabel];
    [self.userLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(20);
        make.centerY.equalTo(self.quitButton);
    }];
    
    [self.view addSubview:self.collectionView];
    self.collectionView.backgroundColor = [UIColor clearColor];
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.top.equalTo(self.quitButton.mas_bottom).offset(20);
        make.height.equalTo(@(255));
    }];
    
    UIButton *enterSeatButton = [self actionButtonFactory:@"上麦" withAction:@selector(enterSeat)];
    UIButton *leaveSeatButton = [self actionButtonFactory:@"下麦" withAction:@selector(leaveSeat)];
    UIButton *lockSeatButton = [self actionButtonFactory:@"锁麦" withAction:@selector(lockSeat)];
    UIButton *muteSeatButton = [self actionButtonFactory:@"闭麦" withAction:@selector(muteSeat)];
    UIStackView *stackView1 = [self stackViewWithViews:@[enterSeatButton, leaveSeatButton, lockSeatButton, muteSeatButton]];
    [self.view addSubview:stackView1];
    [stackView1 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(20);
        make.top.equalTo(self.collectionView.mas_bottom).offset(20);
    }];
    
    UIButton *inviteUserButton = [self actionButtonFactory:@"邀请用户上麦" withAction:@selector(pickUserToSeat)];
    UIButton *kickUerButton = [self actionButtonFactory:@"踢用户下麦" withAction:@selector(kickUserOffSeat)];
    UIStackView *stackView2 = [self stackViewWithViews:@[inviteUserButton, kickUerButton]];
    [self.view addSubview:stackView2];
    [stackView2 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(20);
        make.top.equalTo(stackView1.mas_bottom).offset(20);
    }];
}

- (UIButton *)actionButtonFactory:(NSString *)title withAction:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor colorFromHexString:@"#EF499A"];
    button.layer.cornerRadius = 6;
    [button setTitle:title forState: UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState: UIControlStateNormal];
    [button addTarget:self action:action forControlEvents: UIControlEventTouchUpInside];
    [[button.widthAnchor constraintGreaterThanOrEqualToConstant:70] setActive:YES];
    return button;
}

- (UIStackView *)stackViewWithViews:(NSArray *)views {
    UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:views];
    stackView.axis = UILayoutConstraintAxisHorizontal;
    stackView.spacing = 10;
    stackView.alignment = UIStackViewAlignmentCenter;
    stackView.distribution = UIStackViewDistributionEqualSpacing;
    return stackView;
}

- (void)showInputAlertWithTitle:(NSString *)title withTextField:(BOOL)hasTextField withCompletion:(void (^)(NSString* text))completion {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:@"" preferredStyle:UIAlertControllerStyleAlert];
    if (hasTextField) {
        [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = @"请输入";
            textField.keyboardType = UIKeyboardTypeNumberPad;
        }];
    }
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (hasTextField) {
            NSString *value = [[alertController textFields][0] text];
            completion(value);
        } else {
            completion(nil);
        }
    }];
    [alertController addAction:confirmAction];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"Canelled");
    }];
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

// 上麦
- (void)enterSeat {
    [self showInputAlertWithTitle:@"输入麦位序号" withTextField:YES withCompletion:^(NSString* value) {
        NSUInteger seatIndex = value.integerValue;
        [[RCVoiceRoomEngine sharedInstance] enterSeat:seatIndex success:^{
            [SVProgressHUD showSuccessWithStatus:@"上麦成功"];
        } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
            [SVProgressHUD showSuccessWithStatus:@"上麦失败"];
        }];
    }];
}

// 下麦
- (void)leaveSeat {
    [[RCVoiceRoomEngine sharedInstance] leaveSeatWithSuccess:^{
        [SVProgressHUD showSuccessWithStatus:@"下麦成功"];
    } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
        [SVProgressHUD showSuccessWithStatus:@"下麦失败"];
    }];
}

// 锁麦
- (void)lockSeat {
    [self showInputAlertWithTitle:@"输入麦位序号" withTextField:YES withCompletion:^(NSString * text) {
        NSUInteger seatIndex = text.integerValue;
        RCVoiceSeatInfo *seatInfo = self.seatlist[seatIndex];
        BOOL isLock = (seatInfo.status == RCSeatStatusLocking) ? NO : YES;
        [[RCVoiceRoomEngine sharedInstance] lockSeat:seatIndex lock:isLock success:^{
            [SVProgressHUD showSuccessWithStatus:@"锁麦成功"];
        } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
            [SVProgressHUD showSuccessWithStatus:@"锁麦失败"];
        }];
    }];
}

// 离开房间
- (void)quitRoom {
    [[RCVoiceRoomEngine sharedInstance] leaveRoom:^{
        [SVProgressHUD showSuccessWithStatus:@"离开房间成功"];
        [self.navigationController popViewControllerAnimated:true];
    } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
        [SVProgressHUD showSuccessWithStatus:@"离开房间失败"];
    }];
}

// 闭麦
- (void)muteSeat {
    [self showInputAlertWithTitle:@"输入麦位序号" withTextField:YES withCompletion:^(NSString * text) {
        NSUInteger seatIndex = text.integerValue;
        RCVoiceSeatInfo *seatInfo = self.seatlist[seatIndex];
        BOOL isMute = !seatInfo.isMuted;
        NSString *muteString = (isMute ? @"闭麦" : @"取消闭麦");
        [[RCVoiceRoomEngine sharedInstance] muteSeat:seatIndex mute:isMute success:^{
            [SVProgressHUD showSuccessWithStatus:[muteString stringByAppendingString:@"成功"]];
        } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
            [SVProgressHUD showSuccessWithStatus:[muteString stringByAppendingString:@"失败"]];
        }];
    }];
}

// 邀请上麦
- (void)pickUserToSeat {
    [self showInputAlertWithTitle:@"输入邀请上麦的用户id" withTextField:YES withCompletion:^(NSString *text) {
        [[RCVoiceRoomEngine sharedInstance] pickUserToSeat:text success:^{
            [SVProgressHUD showSuccessWithStatus:@"发送邀请成功"];
        } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
            [SVProgressHUD showErrorWithStatus:@"发送邀请失败"];
        }];
    }];
}

// 强制下麦
- (void)kickUserOffSeat {
    [self showInputAlertWithTitle:@"输入强制下麦的用户id" withTextField:YES withCompletion:^(NSString *text) {
        [[RCVoiceRoomEngine sharedInstance] kickUserFromSeat:text success:^{
            [SVProgressHUD showSuccessWithStatus:@"强制下麦发送成功"];
        } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
            [SVProgressHUD showErrorWithStatus:@"强制下麦发送失败"];
        }];
    }];
}

#pragma mark - Create And Join Method

- (void)createVoiceRoom:(NSString *)roomId info:(RCVoiceRoomInfo *)roomInfo {
    // 关于roomId，真实环境中一般是调用自己的业务服务器接口，创建一个语聊房，业务服务器返回一个roomId
    // 这里便于演示使用一个固定的roomId
    [[RCVoiceRoomEngine sharedInstance] createAndJoinRoom:roomId room:roomInfo success:^{
        [SVProgressHUD showSuccessWithStatus:@"创建成功"];
    } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
        [SVProgressHUD showSuccessWithStatus:@"创建失败"];
    }];
}

- (void)joinVoiceRoom:(NSString *)roomId {
    [[RCVoiceRoomEngine sharedInstance] joinRoom:roomId success:^{
        [SVProgressHUD showSuccessWithStatus:@"加入房间成功"];
    } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
        [SVProgressHUD showSuccessWithStatus:@"加入房间失败"];
    }];
}

#pragma mark - Private Method

- (NSInteger)emptySeatIndex {
    for (int i = 0; i<self.seatlist.count; i++) {
        RCVoiceSeatInfo *info = self.seatlist[i];
        if (info.status == RCSeatStatusEmpty) {
            return i;
        }
    }
    return -1;
}

#pragma mark - lazy Init

- (UICollectionView *)collectionView {
    if (!_collectionView) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.itemSize = CGSizeMake(75, 75);
        layout.minimumInteritemSpacing = 15;
        layout.minimumLineSpacing = 15;
        layout.scrollDirection = UICollectionViewScrollDirectionVertical;
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
        [_collectionView registerClass:[SeatInfoCollectionViewCell class] forCellWithReuseIdentifier:cellIdentifier];
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.contentInset = UIEdgeInsetsMake(0, 20, 0, 20);
    }
    return _collectionView;
}

- (UIImageView *)backgroundImageView {
    if (!_backgroundImageView) {
        _backgroundImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"roombackground.jpeg"]];
    }
    return _backgroundImageView;
}

- (NSArray<RCVoiceSeatInfo *> *)seatlist {
    if (!_seatlist) {
        _seatlist = [NSArray array];
    }
    return _seatlist;
}

- (UIButton *)quitButton {
    if (!_quitButton) {
        _quitButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_quitButton setImage:[UIImage imageNamed:@"white_quite_icon"] forState:UIControlStateNormal];
        [_quitButton addTarget:self action:@selector(quitRoom) forControlEvents:UIControlEventTouchUpInside];
    }
    return _quitButton;
}

- (UILabel *)userLabel {
    if (!_userLabel) {
        _userLabel = [[UILabel alloc] init];
        _userLabel.font = [UIFont systemFontOfSize:14];
        _userLabel.textColor = [UIColor whiteColor];
    }
    return _userLabel;
}

#pragma mark - CollectionView Delegate & DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _seatlist.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SeatInfoCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    [cell updateCell:self.seatlist[indexPath.row] withSeatIndex:indexPath.row];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [[RCVoiceRoomEngine sharedInstance] enterSeat:indexPath.row success:^{
        [SVProgressHUD showSuccessWithStatus:@"上麦成功"];
    } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
        [SVProgressHUD showSuccessWithStatus:@"上麦失败"];
    }];
}

#pragma mark - VoiceRoomLib Delegate

// 房间信息初始化完毕，可在此方法进行一些初始化操作，例如进入房间房主自动上麦等
- (void)roomKVDidReady {
    
}

// 任何麦位的变化都会触发此回调。
- (void)seatInfoDidUpdate:(NSArray<RCVoiceSeatInfo *> *)seatInfolist {
    self.seatlist = seatInfolist;
    [self.collectionView reloadData];
}

// 任何房间信息的修改都会触发此回调。
- (void)roomInfoDidUpdate:(RCVoiceRoomInfo *)roomInfo {
    self.roomInfo = roomInfo;
}

// 收到被下麦的回调
- (void)kickSeatDidReceive:(NSUInteger)seatIndex {
    [[RCVoiceRoomEngine sharedInstance] leaveSeatWithSuccess:^{
        [SVProgressHUD showSuccessWithStatus:@"被踢下麦"];
    } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
        [SVProgressHUD showErrorWithStatus:@"被踢下麦失败"];
    }];
}

// 聊天室消息回调
- (void)messageDidReceive:(nonnull RCMessage *)message {
    
}

// 被抱麦的回调，userId为邀请你上麦的用户id
- (void)pickSeatDidReceiveBy:(nonnull NSString *)userId {
    [self showInputAlertWithTitle:[NSString stringWithFormat:@"收到来自用户%@的上麦邀请，是否同意", userId] withTextField:NO withCompletion:^(NSString *text) {
        NSInteger emptyIndex = [self emptySeatIndex];
        if (emptyIndex >= 0) {
            [[RCVoiceRoomEngine sharedInstance] enterSeat:emptyIndex success:^{
                [SVProgressHUD showSuccessWithStatus:@"上麦成功"];
            } error:^(RCVoiceRoomErrorCode code, NSString * _Nonnull msg) {
                [SVProgressHUD showErrorWithStatus:@"上麦失败"];
            }];
        } else {
            [SVProgressHUD showErrorWithStatus:@"没有空余麦位"];
        }
    }];
}

// 你发出的连麦申请被接受了。这时可以调用上麦接口直接上麦
- (void)requestSeatDidAccept {
    
}

// 你发出的连麦申请被拒绝了。这时可以调用Hud显示被拒绝信息
- (void)requestSeatDidReject {
    
}

// 申请上麦的列表发生了变化，你可以调用getLatestRequestSeat接口获取最新的申请连麦的用户列表
- (void)requestSeatListDidChange {
    
}

// 房间发生了未知错误
- (void)roomDidOccurError:(RCVoiceRoomErrorCode)code {
    
}

// 通过
- (void)roomNotificationDidReceive:(nonnull NSString *)name content:(nonnull NSString *)content {
    
}

// 某个麦位被锁定时会触发此回调
- (void)seatDidLock:(NSInteger)index isLock:(BOOL)isLock {
    
}

// 某个麦位被静音或解除静音时会触发此回调
- (void)seatDidMute:(NSInteger)index isMute:(BOOL)isMute {
    
}

// 某个麦位有人说话时会触发此回调
- (void)speakingStateDidChange:(NSUInteger)seatIndex speakingState:(BOOL)isSpeaking {
    
}

// 用户进入房间时会触发此回调
- (void)userDidEnter:(nonnull NSString *)userId {
    
}

// 用户上了某个麦位时会触发此回调
- (void)userDidEnterSeat:(NSInteger)seatIndex user:(nonnull NSString *)userId {
    
}

// 用户离开房间时触发此回调
- (void)userDidExit:(nonnull NSString *)userId {
    
}

// 用户被踢出房间时触发此回调
- (void)userDidKickFromRoom:(nonnull NSString *)targetId byUserId:(nonnull NSString *)userId {
    
}

// 用户下麦某个麦位触发此回调
- (void)userDidLeaveSeat:(NSInteger)seatIndex user:(nonnull NSString *)userId {
    
}

// 以下4个为自定义邀请，可不用关心
- (void)invitationDidAccept:(nonnull NSString *)invitationId {
    
}

- (void)invitationDidCancel:(nonnull NSString *)invitationId {
    
}

- (void)invitationDidReceive:(nonnull NSString *)invitationId from:(nonnull NSString *)userId content:(nonnull NSString *)content {
    
}

- (void)invitationDidReject:(nonnull NSString *)invitationId {
    
}

@end
