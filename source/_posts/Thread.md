---
toc: true
title:  Thread
date: 2018-07-08 19:29:41
tags: [Java 并发]
categories: JAVA
---
*Add this line to Using the more label,but it's too short to look bad,addition point length*
<!--more--> 
## 线程的生命周期

|状态|描述|
|:-|:-|
|new|创建状态—>使用new关键字，创建一个线程,但是还没有调用start方法，仅仅由JVM分配内存，并初始化成员变量|
|runnable/start|就緒状态—>调用start()后处于就绪状态，JVM为其创建方法调用栈和程序计数器，但线程并没有开始运行，仅表示可以运行。何时开始，取决于JVM里的线程调度器的调度|
|running|运行状态—>处于就绪状态的线程，获得了CPU，开始执行run()方法，则处于运行状态|
|blocked|阻塞状态—>表示线程阻塞于锁。线程之间需要切换，时间段用完后，系统会剥夺线程占用的资源，让其他线程执行，选择哪个线程，系统会考虑线程的优先级。调用sleep(),调用阻塞式IO方法，等待同步锁，等待通知wait()，suspend(),join()，这些将使得线程进入阻塞状态|
|waiting|等待状态—>进入该状态后需要其他线程做出通知动作，也可以算是阻塞状态。需要notify()唤醒线程，使之进入就绪状态|
|timewaiting|超时等状态状态—>该状态与WAITING不同，它是可以在指定时间内自行返回的。相当于在等待状态基础上，增加了时间的限制，超过了设定的时间限制就会返回到运行状态|
|dead/terminated|死亡状态—>线程执行完毕。run()或call()执行完成,线程抛出未捕获的Exception或Error，调用该线程的stop()，都会结束线程。|
![线程生命周期](/img/thread/003.png)

## 线程的创建
在Java中，创建线程去执行子任务一般有两种方式：继承Thread类和实现Runnable接口。 其中，Thread类本身就实现了Runnable 接口，而使用继承Therad类的方式创建线程的最大局限就是不支持多继承。

````java
//线程创建示例代码
public class ThreadTest {
    public static void main(String[] args) {

        //使用继承Thread类的方式创建线程
        new Thread(){
            @Override
            public void run() {
                System.out.println("Thread");
            }
        }.start();

        //使用实现Runnable接口的方式创建线程
        Thread thread = new Thread(new Runnable() {
            @Override
            public void run() {
                System.out.println("Runnable");
            }
        });
        thread.start();

        //JVM 创建的主线程 main
        System.out.println("main");
    }
}
````

run()方法中只是定义需要执行的任务，并且不需要用户来调用。当通过start()方法启动一个线程之后，若线程获得了CPU执行时间，便进入 run()方法去执行具体的任务。如果用户直接调用run()方法相当于在主线程中执行run()方法，跟普通的方法调用没有任何区别。
## Thread类详解
Thread 类实现了 Runnable 接口，在 Thread 类中，有一些比较关键的属性，比如name是表示Thread的名字，可以通过Thread类的构造器中的参数来指定线程名字，priority表示线程的优先级（最大值为10，最小值为1，默认值为5），daemon表示线程是否是守护线程，target表示要执行的任务。

### start 方法
start()用来启动一个线程，当调用该方法后，相应线程就会进入就绪状态，该线程中的run()方法会在某个时间被调用

### run 方法
run()方法是不需要用户来调用的。当通过start()方法启动一个线程之后，一旦线程获得了CPU执行时间，便进入run()方法体去执行具体的任务。注意，创建线程是必须要重写run()方法，以定义具体要执行的任务
![run方法实现](/img/thread/004.png)

### sleep方法
sleep()方法的作用是在指定的毫秒数内让当前正在执行的线程睡眠，并交出CPU让其去执行其他的任务。当线程睡眠时间满后，不一定会立即得到执行，因为此时CPU正在执行其他的任务。所以说，调用sleep方法相当于让线程进入阻塞状态。该方法有如下两条特征：
* 如果调用了sleep方法，必须捕获InterruptedException异常或将该异常向上层抛出
* sleep方法不会释放锁，也就是说如果当前线程持有对某个对象的锁，则即使调用sleep方法，其他线程也无法访问这个对象
![sleep方法](/img/thread/005.png)

### yield方法
调用yield()方法会让当前线程 交出CPU资源，让CPU去执行 其他 线程，但是，yield()不能控制具体的交出CPU的时间，需要注意的是
* yield()方法只能让拥有相同优先级的线程有获取CPU执行时间的机会
* 调用yield()方法并不会让线程进入阻塞状态，而是让线程重回就绪状态，塔只需要等待重新得到CPU的执行
![yield实现](/img/thread/006.png)

### join方法
假如在main线程 中调用thread.join方法，则main线程会等待thread线程执行完毕或者等待一定的时间。详细地，如果调用的是无参join方法，则等待thread执行完毕；如果调用的是指定了时间参数的join方法，则等待一定的时间。join()方法有三个重载版本：
```` java
public final void join() throws InterruptedException {...}
public final synchronized void join(long millis) throws InterruptedException {...}
public final synchronized void join(long millis, int nanos) throws InterruptedException {...}
````
以join(long millis) 方法为例，其内部调用了Object的wait方法，如下图
![join方法](/img/thread/007.png)
根据以上源代码可以看出，join()方法是通过wait()方法 (Object 提供的方法) 实现的。当 millis == 0 时，会进入 while(isAlive()) 循环，并且只要子线程是活的，宿主线程就不停的等待。 wait(0) 的作用是让当前线程(宿主线程)等待，而这里的当前线程是指 Thread.currentThread() 所返回的线程。所以，虽然是子线程对象调用wait()方法，但是阻塞的是宿主线程。

### interrupt方法
interrupt,顾名思义，即中断的意思。单独调用interrupt方法可以使得处于阻塞状态的线程抛出一个异常，也就是说，它可以用来中断一个正处于阻塞状态的线程；另外，通过interrupted()方法和isInterrupted()方法可以停止正在运行的线程。interrupt方法在JDK中的定义为：
![interrupt方法](/img/thread/008.png)
interrupted()和isInterrupted()方法在JDK中的定义分别为：
![interrupt方法](/img/thread/009.png)

### stop方法
stop()方法已经是一个废弃的方法，它是一个不安全的方法。因为调用 stop()方法会直接终止run方法的调用，并且会抛出一个ThreadDeath错误，如果线程持有某个对象的话，会完全释放锁，导致对象状态不一致。所以，stop()方法基本是不会被用到的。

### 线程暂停/恢复
暂停线程意味着此线程还可以恢复运行，我们可以使用suspend()方法暂停线程，使用resume()方法恢复线程的执行，但是这两个方法已被废弃，因为他们具有固有的死锁倾向。如果目标线程挂起时在保护关键系统资源的监视器上保持有锁，则在目标线程重新开始以前，任何线程都不能访问该资源。如果重新开始目标线程的线程想在调用 resume 之前锁定该监视器，则会发生死锁。具体地，在使用 suspend 和 resume 方法时，如果使用不当，极易造成公共的同步对象的独占，使得其他线程无法得到公共同步对象锁，从而造成死锁

## 线程常用操作


### currentThread方法
currentThread()方法返回代码正在执行当前代码的线程。其在Thrad类中定义如下:
![currentThread方法](/img/thread/010.png)

### isAlive
isAlve()的功能是判断调用该方法的线程是否处于活动状态。其中，活动状态是指线程已经start（无论是否获得CPU资源并运行）且尚未结束
![isAlive方法](/img/thread/011.png)

### getId
getId()作用是获取线程唯一标识，由JVM自动给出
![getId方法](/img/thread/012.png)

### getName/setName
用来得到或者设置线程名称。如果我们不手动设置线程的名字，JVM会为该线程自动创建一个表示名，形式为;Thread-数字

### getPriority和setPriority
在操作系统中，线程可以划分优先级，优先级较高的线程得到的CPU资源较多，也就是CPU优先执行优先级较高的线程。设置线程优先级有助于帮助“线程规划器”确定在下一次选择哪个线程 来获得CPU资源。在Java中，线程的优先级分为1~10这十个等级，如果小于1或大于10，则JDK抛出异常IllegalArgumentException,JDK中 使用3个常量来预置定义优先级的值
````java
public static final int MIN_PRIORITY = 1; 
public static final int NORM_PRIORITY = 5; 
public static final int MAX_PRIORITY = 10; 
````
![setPriority方法](/img/thread/013.png)

#### 线程优先级
##### 继承性
在 Java 中，线程的优先级具有继承性，比如 A 线程启动 B 线程， 那么 B 线程的优先级与 A 是一样的。
##### 规则性和随机性
线程的优先级具有一定的规则性，也就是CPU尽量将执行资源让给优先级比较高的线程。特别地，高优先级的线程总是大部分先执行完，但并不一定所有的高优先级线程都能先执行完。

### 守护线程(Daemon)
在 Java 中，线程可以分为两种类型，即用户线程和守护线程。守护线程是一种特殊的线程，具有“陪伴”的含义：当进程中不存在非守护线程时，则守护线程自动销毁，典型的守护线程就是垃圾回收线程。任何一个守护线程都是整个JVM中所有非守护线程的保姆，只要当前JVM实例中存在任何一个非守护线程没有结束，守护线程就在工作；只有当最后一个非守护线程结束时，守护线程才随着JVM一同结束工作。 在 Thread类中，方法 setDaemon() 的定义为：
![setPriority方法](/img/thread/014.png)

## 小结
###  对于上述线程的各项基本操作，其 所操作的对象 满足：
* 若该操作是静态方法，也就是说，该方法属于类而非具体的某个对象，那么该操作的作用对象就是 currentThread() 方法所返回 Thread 对象
* 若该操作是实例方法，也就是说，该方法属于对象，那么该操作的作用对象就是调用该方法的 Thread 对象。
### 对于上述线程的各项基本操作，有：
* 线程一旦被阻塞，就会释放 CPU.
* 当线程出现异常且没有捕获处理时，JVM会自动释放当前线程占用的锁，因此不会由于异常导致出现死锁现象。
* 对于一个线程，CPU 的释放 与 锁的释放没有必然联系。