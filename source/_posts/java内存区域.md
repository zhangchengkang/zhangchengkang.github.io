---
title: JVM内存区域
date: 2018-05-23 21:36:06
author: kangshifu
img: 
top: true
cover: false
coverImg: 
password: 
toc: true
mathjax: false
summary: 
categories: JVM
tags:
  - Java 
  - JVM


---

<!--more-->  

![运行时数据区](/img/jvm/jvm001.png)
## 1. 线程独占区
### 1.1 程序计数器（Program Counter Register）
* 程序计数器是一块较小的内存空间,它可以看做是当前线程所执行的字节码的行号指示器
* 字节码解释器工作时就是通过改变这个计数器的值来选取下一条需要执行的字节码指令,分支、循环、跳转、异常处理、线程恢复等基础功能都需要依赖这个计数器来完成
* 由于JVM的多线程是通过并发来实现的,在任何一个确定的时刻,一个处理器都只会执行一条线程中的指令,故其是线程私有的内存
* 如果线程执行的是一个Java方法，这个计数器记录的是正在执行的虚拟机字节码指令的地址；如果正在执行的是Native方法，这个计数器值则为空（undefined）。此内存区域是唯一一个在虚拟机规范中不会出现OutofMemoryError的区域
### 1.2 Java虚拟机栈(Java Virtual Machine Stacks)
* 存储内容: 基础数据类型的对象和自定义对象的引用
* Java虚拟机栈也是线程私有的，它的生命周期与线程相同,这块内存区域就是我们常说的"栈
* 虚拟机描述的是Java方法执行的内存模型:每个方法在执行的同时都会创建一个栈帧(Stack Frame) 用于存储局部变量表、操作数栈、动态链接、方法出口等信息。每一个方法从调用到执行完成的过程,就对应着一个栈帧在虚拟机栈中入栈到出栈的过程
* 局部变量表存放了编译期可知的各种基本类型（boolean,byte,char,short,int,float,long,double）、对象引用和returnAddress(指向了一条字节码指令的地址)类型。
* 栈分为三个部分:  基本类型变量区、执行环境上下文、操作指令区
### 1.3 本地方法栈(Native Method Stack)
* 本地方法栈与虚拟机栈所发挥的作用是非常相似的，他们之间的区别不过是虚拟机执行java方法，也就是字节码服务，而本地方法栈则为虚拟机使用的Native方法服务。甚至有的虚拟机(譬如Sun HotSpot虚拟机)直接就把虚拟机栈和本地方法栈合二为一
## 2. 线程共享区
### 2.1 Java堆(Java Heap)
* 存储内容:存储的全部是对象,每个对象都包含一个与之对应的class的信息(目的是得到操作指令)
* 从内存回收的角度来看，由于现在收集器基本都采用分代收集算法，所以还可以细分为：新生代（Young Generation）、老年代（Old Generation）。对于新生代又分为：Eden空间，From Survivor空间，ToSurvivor空间
* 从内存分配的角度来看，线程共享的Java堆中可能划分出多个线程私有的分配缓冲区（Thread Local Allocation Buffer,TLAB）
### 2.2 方法区(Method Area)
* 存储内容: 所有的class(字节码文件)和static变量,方法区中包含的都是在整个程序中永远唯一的元素
* 对于JVM的方法区，可能听得最多的是另外一个说法——永久代（Permanent Generation），呼应堆的新生代和老年代。方法区和堆的划分是JVM规范的定义，而不同虚拟机有不同实现，对于Hotspot虚拟机来说，将方法区纳入GC管理范围，这样就不必单独管理方法区的内存，所以就有了”永久代“这么一说，但使用永久代来实现方法区现在看来并不是很好，因为这样更容易遇到内存溢出的问题，（永久代有-XX:MaxPermSize的上限，J9和JRockit只要没有触碰到进程可用内存的上限，例如64为系统中的4GB，就不会有问题），而且有极少数方法（例如String.intern()）会因为这个原因导致不同虚拟机下有不同的表现。因此，现在对于HotSpot虚拟机，已经改为采用Native Memory来实现方法区规划了，而且在JDK1.7的HotSpot中，已经把原本放在永久代的字符串常量池移出。
**举例**
现设置JVM参数为”-XX:MaxPermSize=20M”（方法区最大内存为20M）
```java
public class Test {

    public static void main(String[] args) {
        List<String> list = new ArrayList<String>();
        int i = 0;
        while (true) {
            list.add(String.valueOf(i++).intern());   
        }
    }
}
```
* 实际上对于以上代码，在JDK6、JDK7、JDK8运行结果均不一样。原因就在于字符串常量池在JDK6的时候还是存放在方法区（永久代）所以它会抛出OutOfMemoryError:Permanent Space；而JDK7后则将字符串常量池移到了Java堆中，上面的代码不会抛出OOM，若将堆内存改为20M则会抛出OutOfMemoryError:Java heap space；至于JDK8则是纯粹取消了方法区这个概念，取而代之的是”元空间（Metaspace）“，所以在JDK8中虚拟机参数”-XX:MaxPermSize”也就没有了任何意义，取代它的是”-XX:MetaspaceSize“和”-XX:MaxMetaspaceSize”等。
#### 2.2.1 运行时常量池(Runtime Constant Pool)
* 运行时常量池是方法区的一部分,Class文件中除了有类的版本、字段、方法、接口等描述信息外,还有一项是常量池,用于存放编译期生成的各种字面量和符号引用,这部分内容将在类加载后进入方法区的运行时常量池中存放
* Java语言并不要求常量一定只有编译期才能产生，也就是并非预置入Class文件中常量池的内容才能进入方法区运行时常量池，运行期间也可能将新的常量放入池中，这种特性被开发人员利用得比较多的是String类的intern()方法
```java
 public static void main(String[] args) {

        String s1 = "abc";
        String s2 = "abc";

        String s3= new String("abc");

        System.out.println(s1 == s2);　//true
        System.out.println(s2 == s3);  //false
        System.out.println(s2 == s3.intern());  //true 
    }
```
## 3. 直接内存
* 直接内存并不是虚拟机运行时数据区的一部分，也不是Java虚拟机规范中定义的内存区域。但是这部分内存也被频繁的使用，而且也可能导致OutOfMemoryError异常出现
* 在ＪＤＫ1.4中新加入了NIO类，引入了一种基于通道与缓冲区的I/O方式，它可以使用Native函数库直接分配堆外内存，然后通过存储在Java堆中的DirectByteBuffer对象作为这块内存的引用进行操作。这样能在一些场景中显著提高性能，因为避免了在Java堆中来回复制数据。
## 4.总结
![总结](/img/jvm/jvm002.png)

