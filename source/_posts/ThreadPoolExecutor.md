---
toc: true
title:  ThreadPoolExecutor
date: 2019-10-07 14:52:36
tags: [Java 并发]
categories: JAVA

---

*There is a time to speak and a time to be silent*
<!--more--> 



### 类图

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/%E7%BA%BF%E7%A8%8B%E6%B1%A0%E7%B1%BB%E5%9B%BE.jpg)

- Executor是一个顶层接口，在它里面只声明了一个方法execute(Runnable)，返回值为void，参数为Runnable类型，从字面意思可以理解，就是用来执行传进去的任务的；

- 然后ExecutorService接口继承了Executor接口，并声明了一些方法：submit、invokeAll、invokeAny以及shutDown等；

- 抽象类AbstractExecutorService实现了ExecutorService接口，基本实现了ExecutorService中声明的所有方法；

- 然后ThreadPoolExecutor继承了类AbstractExecutorService。

### 构造方法

```java
 public ThreadPoolExecutor(int corePoolSize,
                              int maximumPoolSize,
                              long keepAliveTime,
                              TimeUnit unit,
                              BlockingQueue<Runnable> workQueue,
                              ThreadFactory threadFactory,
                              RejectedExecutionHandler handler) {
        if (corePoolSize < 0 ||
            maximumPoolSize <= 0 ||
            maximumPoolSize < corePoolSize ||
            keepAliveTime < 0)
            throw new IllegalArgumentException();
        if (workQueue == null || threadFactory == null || handler == null)
            throw new NullPointerException();
        this.corePoolSize = corePoolSize;
        this.maximumPoolSize = maximumPoolSize;
        this.workQueue = workQueue;
        this.keepAliveTime = unit.toNanos(keepAliveTime);
        this.threadFactory = threadFactory;
        this.handler = handler;
    }
```



- **int corePoolSize** : **线程池中的核心线程数**，当提交一个任务时，线程池创建一个新线程执行任务，直到当前线程数等于corePoolSize, 即使有其他空闲线程能够执行新来的任务, 也会继续创建线程；如果当前线程数为corePoolSize，继续提交的任务被保存到阻塞队列中，等待被执行；如果执行了线程池的prestartAllCoreThreads()方法，线程池会提前创建并启动所有核心线程。
- **int maximumPoolSize** : **线程池最大线程数。**它表示在线程池中最多能创建多少个线程；当阻塞队列是无界队列, 则maximumPoolSize则不起作用, 因为无法提交至核心线程池的线程会一直持续地放入workQueue.
- **long keepAliveTime** : **表示线程没有任务执行时最多保持多久时间会终止。**默认情况下，当线程池中的线程数大于corePoolSize时，如果一个线程空闲的时间达到keepAliveTime，则会终止，直到线程池中的线程数不超过corePoolSize。但是如果调用了allowCoreThreadTimeOut(boolean)方法，在线程池中的线程数不大于corePoolSize时，keepAliveTime参数也会起作用，直到线程池中的线程数为0；
- **TimeUnit unit** : 参数keepAliveTime的时间单位

```java
TimeUnit.DAYS;               //天
TimeUnit.HOURS;             //小时
TimeUnit.MINUTES;           //分钟
TimeUnit.SECONDS;           //秒
TimeUnit.MILLISECONDS;      //毫秒
TimeUnit.MICROSECONDS;      //微妙
TimeUnit.NANOSECONDS;       //纳秒
```



- **BlockingQueue<Runnable>  workQueue** : **阻塞队列，用来存储等待执行的任务**

```java
ArrayBlockingQueue;//基于数组结构的有界阻塞队列，按FIFO排序任务；
LinkedBlockingQueue;//基于链表结构的阻塞队列，按FIFO排序任务，吞吐量通常要高于ArrayBlockingQuene；
SynchronousQueue;//一个不存储元素的阻塞队列，每个插入操作必须等到另一个线程调用移除操作，否则插入操作一直处于阻塞状态，吞吐量通常要高于LinkedBlockingQuene；
PriorityBlockingQueue;//具有优先级的无界阻塞队列；
//LinkedBlockingQueue比ArrayBlockingQueue在插入删除节点性能方面更优，但是二者在put(), take()任务的时均需要加锁，SynchronousQueue使用无锁算法，根据节点的状态判断执行，而不需要用到锁，其核心是Transfer.transfer().
```



- **ThreadFactory threadFactory** : 线程工厂，主要用来创建线程，默认为`DefaultThreadFactory`
- **RejectedExecutionHandler handler** : **表示当拒绝处理任务时的策略**

```java

ThreadPoolExecutor.AbortPolicy//丢弃任务并抛出RejectedExecutionException异常，默认。 
ThreadPoolExecutor.DiscardPolicy//也是丢弃任务，但是不抛出异常。 
ThreadPoolExecutor.DiscardOldestPolicy//丢弃队列最前面的任务，然后重新尝试执行任务（重复此过程）
ThreadPoolExecutor.CallerRunsPolicy//用调用者所在的线程来执行任务
```

### 三种线程池

　　　　线程池都继承了ExecutorService的接口，所以他们都具有ExecutorService的生命周期方法：运行，关闭，终止；

　　　　因为继承了ExecutorService接口，所以它在被创建的时候就是处于运行状态，当线程没有任务执行时，就会进入关闭状态，只有调用了shutdown（）的时候才是正式的终止了这个线程池。

#### newFixedThreadPool

```java
public static ExecutorService newFixedThreadPool(int nThreads) {
        return new ThreadPoolExecutor(nThreads, nThreads,
                                      0L, TimeUnit.MILLISECONDS,
                                      new LinkedBlockingQueue<Runnable>());
    }
```

线程池的线程数量达corePoolSize后，即使线程池没有可执行任务时，也不会释放线程。

FixedThreadPool的工作队列为无界队列LinkedBlockingQueue(队列容量为Integer.MAX_VALUE), 这会导致以下问题:
- 线程池里的线程数量不超过corePoolSize,这导致了maximumPoolSize和keepAliveTime将会是个无用参数
- 由于使用了无界队列, 所以FixedThreadPool永远不会拒绝, 即饱和策略失效

#### newSingleThreadExecutor

```java
public static ExecutorService newSingleThreadExecutor() {
        return new FinalizableDelegatedExecutorService
            (new ThreadPoolExecutor(1, 1,
                                    0L, TimeUnit.MILLISECONDS,
                                    new LinkedBlockingQueue<Runnable>()));
    }
```

　　　　初始化的线程池中只有一个线程，如果该线程异常结束，会重新创建一个新的线程继续执行任务，唯一的线程可以保证所提交任务的顺序执行.

　　　　由于使用了无界队列, 所以SingleThreadPool永远不会拒绝, 即饱和策略失效

#### newCachedThreadPool

```java
public static ExecutorService newCachedThreadPool() {
        return new ThreadPoolExecutor(0, Integer.MAX_VALUE,
                                      60L, TimeUnit.SECONDS,
                                      new SynchronousQueue<Runnable>());
    }
```

- 初始化一个可以缓存线程的线程池，默认缓存60s，线程池的线程数可达到Integer.MAX_VALUE，即2147483647，内部使用SynchronousQueue作为阻塞队列；

- 和newFixedThreadPool创建的线程池不同，newCachedThreadPool在没有任务执行时，当线程的空闲时间超过keepAliveTime，会自动释放线程资源，当提交新任务时，如果没有空闲线程，则创建新线程执行任务，会导致一定的系统开销；

  **所以，使用该线程池时，一定要注意控制并发的任务数，否则创建大量的线程可能导致严重的性能问题。**



### 源码分析

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/%E7%BA%BF%E7%A8%8B%E6%B1%A0%E5%8E%9F%E7%90%86.png)

#### 内部状态

```java
/*
 *可以将这个参数看成是一个三十二位的二进制数，
 *其中前三位表示线程池的状态，
 *后二十九位表示线程池中工作线程的数量
 */
private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));
private static final int COUNT_BITS = Integer.SIZE - 3;
//CAPACITY值为：00011111111111111111111111111111
private static final int CAPACITY   = (1 << COUNT_BITS) - 1;
 
//RUNNING状态表示线程池可以接受任务正常工作
private static final int RUNNING    = -1 << COUNT_BITS;
//SHUTDOWN状态表示线程池不接受任务，但如果阻塞队列中还有任务，会将阻塞队列中的任务执行完
private static final int SHUTDOWN   =  0 << COUNT_BITS;
//STOP状态表示线程池不接受任务，也不会执行阻塞队列中的任务，即使阻塞队列中还存在任务
private static final int STOP       =  1 << COUNT_BITS;
// 所有的任务都已经终止
private static final int TIDYING    =  2 << COUNT_BITS;
//terminated()方法已经执行完成
private static final int TERMINATED =  3 << COUNT_BITS;
 
//获取线程池的状态，一般会用形参rs表示,在后面rs参数一般表示线程池状态
private static int runStateOf(int c)     { return c & ~CAPACITY; }
//获取线程池工作线程的数量，一般用形参wc表示
private static int workerCountOf(int c)  { return c & CAPACITY; }
private static int ctlOf(int rs, int wc) { return rs | wc; }
```

#### execute

1. 当工作线程数量小于核心线程数量的时候，会将任务交给addWorker方法，addWorker方法会创建新的线程来处理这个任务
2. 当工作线程数量大于和核心线程数量并且线程池的工作状态是running的时候，会将任务放入到阻塞队列中
3. 当阻塞队列已经满了，会将任务交给addWorker方法处理
4. 当交给addWorker方法处理失败或是线程池的状态不是running的时候，会调用线程池的拒绝策越。

```java
public void execute(Runnable command) {
        if (command == null)
            throw new NullPointerException();
        //如果当前线程数小于核心线程数大小执行addWorker()方法，增加一个线程执行
        int c = ctl.get();
        if (workerCountOf(c) < corePoolSize) {
            //成功执行addWorker()就返回
            if (addWorker(command, true))
                return;
            //没有成功执行获取最新的当前线程数
            c = ctl.get();
        }
        //如果是运行状态，并且加入等待队列成功执行if块（额外含义：线程池是运行状态已经达到核心线程数，优先放入队列）
        if (isRunning(c) && workQueue.offer(command)) {//1
            //先获取最新的线程数
            int recheck = ctl.get();
            //再次判断如果线程池不是运行态了并且移除本次提交任务成功，执行拒绝操作
            if (! isRunning(recheck) && remove(command))
                reject(command);
            //如果是运行状态，或者线程不是运行态但是移除任务队列失败，
            //则检查是否有工作线程在消费队列，如果有则什么都不做（可以确保刚提交进队列的任务被完成），
            //如果没有需要建立一个消费线程用来消费刚刚提交的任务
            else if (workerCountOf(recheck) == 0)
                addWorker(null, false);//2
        }
        //如果不是运行态或者加入队列失败那么尝试执行提交过来的任务，如果执行失败，走拒绝操作（额外含义：核心线程数满了，队列也满了，尝试建立新的线程消费，新线程数要小于最大线程数）
        else if (!addWorker(command, false))
            reject(command);
    }
```



#### addWorker

addWorker方法是生成一个新的工作线程来开启任务。Worker就将工作线程和任务封装到了自己内部，我们可以将Worker看成就是一个工作线程，至于Worker是如何执行任务和从阻塞队列中取任务，那就是Worker的事了

````java
private boolean addWorker(Runnable firstTask, boolean core) {
    retry:
    for (;;) {
        int c = ctl.get();
        int rs = runStateOf(c);
 
        /*
         * 可以将if条件里面的判断条件这样看：
         * rs >= SHUTDOWN &&(rs != SHUTDOWN ||firstTask != null || workQueue.isEmpty())
         * 所以在这里能进if，让addWorker返回false的情况有这样几种
         * 1.当线程池的状态是stop
         * 2.当线程池的状态是shutdown的话，firstTask不为空
         * 3.当线程池的状态是shutdown的话，队列是空的
         * 以上三种情况返回false
         */
        if (rs >= SHUTDOWN &&
            ! (rs == SHUTDOWN &&
               firstTask == null &&
               ! workQueue.isEmpty()))
            return false;
 
        for (;;) {
            int wc = workerCountOf(c);
            /*
             * 当传回core传true的时候，比较当前线程池工作线程数和核心线程数做比较
             * 当传回core传false的时候，比较当前线程池工作线程数和最大线程数做比较
             * 如果当前线程数都是大于等于他们的，直接返回false
             */
            if (wc >= CAPACITY ||
                wc >= (core ? corePoolSize : maximumPoolSize))
                return false;
            //利用cas函数增加线程池工作线程数，如果成功就直接跳出这两层循环
            if (compareAndIncrementWorkerCount(c))
                break retry;
            c = ctl.get();  // Re-read ctl
            if (runStateOf(c) != rs)
                continue retry;
            // else CAS failed due to workerCount change; retry inner loop
        }
    }
 
    boolean workerStarted = false;
    boolean workerAdded = false;
    Worker w = null;
    try {
        final ReentrantLock mainLock = this.mainLock;
        //Worker是线程池的一个内部类，其实完成任务和从队列中取任务都是在Worker中完成的
        w = new Worker(firstTask);
        final Thread t = w.thread;
        if (t != null) {
            mainLock.lock();
            try {
                int c = ctl.get();
                int rs = runStateOf(c);
                 
                if (rs < SHUTDOWN ||
                    (rs == SHUTDOWN && firstTask == null)) {
                    if (t.isAlive()) // precheck that t is startable
                        throw new IllegalThreadStateException();
                    workers.add(w);
                    int s = workers.size();
                    if (s > largestPoolSize)
                        largestPoolSize = s;
                    workerAdded = true;
                }
            } finally {
                mainLock.unlock();
            }
            //当将任务放到任务队列（不同于阻塞队列）成功后，启动工作线程,执行firstTask任务
 
            if (workerAdded) {
                t.start();
                workerStarted = true;
            }
        }
    } finally {
        if (! workerStarted)
            addWorkerFailed(w);
    }
    return workerStarted;
}
````



#### Woker

启动一个 Worker对象中包含的线程 thread, 就相当于要执行 runWorker()方法, 并将该 Worker对象作为该方法的参数.

```java
private final class Worker extends AbstractQueuedSynchronizer implements Runnable
 
         final Thread thread;
        /** Initial task to run.  Possibly null. */
        Runnable firstTask;
 
        Worker(Runnable firstTask) {
            setState(-1); // inhibit interrupts until runWorker
            //指向提交过来的任务
            this.firstTask = firstTask;
            //指向自己
            this.thread = getThreadFactory().newThread(this);
        }

        public void run() {
            runWorker(this);
        }
 
}
```

#### runWorker

```java
/*
 * 这个方法是执行任务，当前任务执行完后会向队列里面取任务,
 * 如果队列里也没任务了，就会将这个工作线程从工作线程队列中移除
 * 所以线程池几个线程执行多个任务就在这里体现了，而不是
 * 一个线程执行一个任务
 */
final void runWorker(Worker w) {
	//工作线程
    Thread wt = Thread.currentThread();
    Runnable task = w.firstTask;
    w.firstTask = null;
    w.unlock(); // allow interrupts
    boolean completedAbruptly = true;
    try {
    	//任务执行完后，getTask方法接着从队列中取任务
        while (task != null || (task = getTask()) != null) {
            w.lock();
            // If pool is stopping, ensure thread is interrupted;
            // if not, ensure thread is not interrupted.  This
            // requires a recheck in second case to deal with
            // shutdownNow race while clearing interrupt
            if ((runStateAtLeast(ctl.get(), STOP) ||
                 (Thread.interrupted() &&
                  runStateAtLeast(ctl.get(), STOP))) &&
                !wt.isInterrupted())
                wt.interrupt();
            try {
            	//如果没有继承ThreadPoolExecutor实现这个方法，这个方法是没有执行动作的
                beforeExecute(wt, task);
                Throwable thrown = null;
                try {
                	//任务执行
                    task.run();
                } catch (RuntimeException x) {
                    thrown = x; throw x;
                } catch (Error x) {
                    thrown = x; throw x;
                } catch (Throwable x) {
                    thrown = x; throw new Error(x);
                } finally {
                	//如果没有继承ThreadPoolExecutor实现这个方法，这个方法是没有执行动作的
                    afterExecute(task, thrown);
                }
            } finally {
                task = null;
                w.completedTasks++;
                w.unlock();
            }
        }
        completedAbruptly = false;
    } finally {
    	//走到这里说明队列里的任务都已经被执行完,移除工作线程
        processWorkerExit(w, completedAbruptly);
    }
}
```

#### getTask

```java
import java.util.concurrent.TimeUnit;
 
/*
 * 从阻塞队列中取任务，取任务有三种情况发生
 * 1.渠道任务并返回任务
 * 2.没有取到任务，返回null,这个工作线程被回收
 * 3.没有取到任务，阻塞在向阻塞队列取任务这里
 * 第三点就是线程池中的空闲任务是如何存在的
 */
private Runnable getTask() {
    boolean timedOut = false; // Did the last poll() time out?
 
    retry:
    for (;;) {
        int c = ctl.get();
        int rs = runStateOf(c);
 
        //当线程池的工作状态是stop，就减少工作线程数，返回null
        //当线程池的工作状态是SHUTDOWN并且队列是空的时候，就减少工作线程数，返回null
        if (rs >= SHUTDOWN && (rs >= STOP || workQueue.isEmpty())) {
            decrementWorkerCount();
            return null;
        }
 
        boolean timed;      // Are workers subject to culling?
 
        for (;;) {
            int wc = workerCountOf(c);
            /*
             * 当允许核心线程超时后被收回或者是工作线程数大于核心线程数
             * 这两种情况下都是一定要回收工作线程的
             */
            timed = allowCoreThreadTimeOut || wc > corePoolSize;
            /*
             * 第一次执行这个语句的时候，是一定会进if里面，跳出里面这层循环的，因为初始化的timedOut=false
             * 当不进入这个循环，说明工作线程超时了，工作线程超时一般会返回null;
             */
            if (wc <= maximumPoolSize && ! (timedOut && timed))
                break;
            /*
             * 说明工作线程超时了，工作线程超时一般会返回null;
             *  减少工作线程数量
             */
            if (compareAndDecrementWorkerCount(c))
                return null;
            c = ctl.get();  // Re-read ctl
            if (runStateOf(c) != rs)
                continue retry;
            // else CAS failed due to workerCount change; retry inner loop
        }
 
        try {
        	/*
        	 * timed为true的时候，当工作线程取任务超时就会返回，返回后会被回收
        	 * 当timed为false的时候，说明当前工作线程不需要被回收，所以就可以在向阻塞队列取任务的时候被阻塞
        	 * 这里就提现了线程池中空闲的线程是如何存在的
        	 */
            Runnable r = timed ?
                workQueue.poll(keepAliveTime, TimeUnit.NANOSECONDS) :
                workQueue.take();
            if (r != null)
                return r;
            /*
             * 走到这里，r一定为空，最后会进入到第40行的if里面，还是返回null
             * 当返回null，这个工作线程就会被回收
             * 
             */
            timedOut = true;
        } catch (InterruptedException retry) {
            timedOut = false;
        }
    }
}
```

#### processWorkerExit

```java
/**
 * 减少工作线程数，将工作线程从工作线程队列中移除
 */
private void processWorkerExit(Worker w, boolean completedAbruptly) {
        if (completedAbruptly) // If abrupt, then workerCount wasn't adjusted
            decrementWorkerCount();
 
        final ReentrantLock mainLock = this.mainLock;
        mainLock.lock();
        try {
            completedTaskCount += w.completedTasks;
            workers.remove(w);
        } finally {
            mainLock.unlock();
        }
 
        tryTerminate();
 
        int c = ctl.get();
        if (runStateLessThan(c, STOP)) {
            if (!completedAbruptly) {
                int min = allowCoreThreadTimeOut ? 0 : corePoolSize;
                if (min == 0 && ! workQueue.isEmpty())
                    min = 1;
                if (workerCountOf(c) >= min)
                    return; // replacement not needed
            }
            addWorker(null, false);
        }
    }
```







