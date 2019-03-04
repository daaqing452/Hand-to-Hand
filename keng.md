# iOS开发踩过的坑

### 调试 
* iPhone只能和一个Apple Watch连接
* （好像有时候也不用？）调试的时候，从一个Apple Watch切换到另一个Apple Watch，下一次run可能就会失败。正确的方法貌似是：
   * stop task (可能不必要)
   * clean project (可能不必要)
   * 关掉iPhone的蓝牙
   * 在iPhone的Watch App中切换Apple Watch
   * 打开iPhone的蓝牙
* 如果还是run失败，重启大法好。可能的优先级：iPhone > Xcode > Apple Watch > Mac
* 两个Apple Watch调试还是不方便，不直接连接的Apple Watch的调试信息只能显示在界面上

### WCSession
* WCSession理论上只能用在同一次run的Watch App和iPhone App之间，不同次run的iPhone App不能给Watch App发消息(Watch app is not installed)；但是不同次run的iPhone App和Watch App之间只要连上，Watch App还是可以使用WCSession接口向iPhone App发东西（包括文件）
* WCSession.isReachable基本没什么用，一开始连上以后，断掉蓝牙也是true；所以一种使用方法是两次握手+定时器
* WCSession在断开后可能还能sendMessage并没有错误反馈
* WCSession传文件会有一定延时

### CoreBluetooth
* 使用CoreBluetooth接口，Apple Watch只能当center不能当peripheral，只能iPhone当peripheral
* 在使用CoreBluetooth接口的地方，不能每次唤醒都使用WCSession那几句话，不然后台不跑了
* CoreBluetooth的传输能力及其有限（一次512B左右？）

### Apple Watch的自动息屏
* Apple Watch做一些手势/过一段时间就会息屏，息屏以后整个程序就不工作了；这时必须用HealthKit + workout让它后台运行
* Apple Watch息屏以后，Apple Watch可以使用WCSession想iPhone发东西，但iPhone不能使用WCSession向Apple Watch发东西
* 不是什么东西随便写，然后workout一下都会在后台跑，还跟代码顺序有关系
* 有一些变量要用@property的方式才能再后台使用，有一些不用

### 文件读取
* 利用group共享沙盒貌似需要苹果开发者账号
* 目前读Apple Watch上的文件，只能WCSession从Apple Watch传到iPhone上，然后iPhone使用XCode的浏览Container获取
* 在iPhone中读取外部文件要用bundle，怎么生成bundle网上有教程

### UI
* 添加控件和代码的mapping
   * 按住ctrl键 把控件拖到代码里->添加控件变量
   * 把控件拖到storyboard层级上->添加事件

### C语言兼容
* 要在Objective-C中添加原生C代码，可能需要将文件后缀从m改成mm，所以建议另起一个mm文件好一些
* 机器学习是用opencv库还可以，svm可以在别的地方离线训完扔给iPhone，用opencv给load进来

### 麦克风
* WatchOS不能使用AVAudioSession来使用麦克风
