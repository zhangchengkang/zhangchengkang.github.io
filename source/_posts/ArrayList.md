---
title: ArrayList源码分析
date: 2019-10-03 19:31:16
author: kangshifu
img: 
top: false
cover: false
coverImg: 
password: 
toc: true
mathjax: false
summary: 
categories: Collection
tags:
  - Java 
  - Collection

---





<!--more-->  



##  源码分析

###  成员变量

```java
	/**
     * 默认容量
     */
    private static final int DEFAULT_CAPACITY = 10;

    /**
     * 一个空数组
     * 当用户指定该 ArrayList 容量为 0 时，返回该空数组
     */
    private static final Object[] EMPTY_ELEMENTDATA = {};

    /**
     * 一个空数组实例
     * - 当用户没有指定 ArrayList 的容量时(即调用无参构造函数)，返回的是该数组==>刚创建一个 ArrayList 时，其内数据量为 0。
     * - 当用户第一次添加元素时，该数组将会扩容，变成默认容量为 10(DEFAULT_CAPACITY) 的一个数组===>通过  ensureCapacityInternal() 实现
     * 它与 EMPTY_ELEMENTDATA 的区别就是：该数组是默认返回的，而后者是在用户指定容量为 0 时返回
     */
    private static final Object[] DEFAULTCAPACITY_EMPTY_ELEMENTDATA = {};

    /**
     * ArrayList基于数组实现，用该数组保存数据, ArrayList 的容量就是该数组的长度
     * - 该值为 DEFAULTCAPACITY_EMPTY_ELEMENTDATA 时，当第一次添加元素进入 ArrayList 中时，数组将扩容值 DEFAULT_CAPACITY(10)
     */
    transient Object[] elementData; 

    /**
     * ArrayList实际存储的数据数量
     */
    private int size;
```



###  构造方法

```java
/**
     * 创建一个初试容量的、空的ArrayList
     * @param  initialCapacity  初始容量
     * @throws IllegalArgumentException 当初试容量值非法(小于0)时抛出
     */
    public ArrayList(int initialCapacity) {
        if (initialCapacity > 0) {
            this.elementData = new Object[initialCapacity];
        } else if (initialCapacity == 0) {
            this.elementData = EMPTY_ELEMENTDATA;
        } else {
            throw new IllegalArgumentException("Illegal Capacity: "+
                    initialCapacity);
        }
    }


    /**
     * 无参构造函数：
     * - 创建一个 空的 ArrayList，此时其内数组缓冲区 elementData = {}, 长度为 0
     * - 当元素第一次被加入时，扩容至默认容量 10
     */
    public ArrayList() {
        this.elementData = DEFAULTCAPACITY_EMPTY_ELEMENTDATA;
    }


    /**
     * 创建一个包含collection的ArrayList
     * @param c 要放入 ArrayList 中的集合，其内元素将会全部添加到新建的 ArrayList 实例中
     * @throws NullPointerException 当参数 c 为 null 时抛出异常
     */
    public ArrayList(Collection<? extends E> c) {
        elementData = c.toArray();
        if ((size = elementData.length) != 0) {
            // c.toArray 可能不会返回 Object[]，可以查看 java 官方编号为 6260652 的 bug
            if (elementData.getClass() != Object[].class)
                // 若 c.toArray() 返回的数组类型不是 Object[]，则利用 Arrays.copyOf(); 来构造一个大小为 size 的 Object[] 数组
                elementData = Arrays.copyOf(elementData, size, Object[].class);
        } else {
            // 替换空数组
            this.elementData = EMPTY_ELEMENTDATA;
        }
    }

```



### add

```java
}

    /**
     * 增加指定的元素到ArrayList的最后位置
     * @param e 要添加的元素
     */
    public boolean add(E e) {
        //  检测是否需要扩容
        ensureCapacityInternal(size + 1);  
        //  将新元素插入序列尾部
        elementData[size++] = e;
        return true;
    }

    /**
     *
     * 在指定位置插入新元素，原先在 index 位置的值往后移动一位
     * @param index 指定位置
     * @param element 指定元素
     * @throws IndexOutOfBoundsException
     */
    public void add(int index, E element) {
        rangeCheckForAdd(index);//判断角标是否越界
        ensureCapacityInternal(size + 1);  
        //将 index 及其之后的所有元素都向后移一位
        System.arraycopy(elementData, index, elementData, index + 1,
                size - index);
        //将新元素插入至 index 处
        elementData[index] = element;
        size++;
    }
```





### 扩容

```java
	/**
     * 私有方法：明确 ArrayList 的容量，提供给本类使用的方法
     * - 用于内部优化，保证空间资源不被浪费：尤其在 add() 方法添加时起效
     * @param minCapacity    指定的最小容量
     */
    private void ensureCapacityInternal(int minCapacity) {
        // 若 elementData == {}，则取  默认容量和参数 minCapacity 之间的最大值
        if (elementData == DEFAULTCAPACITY_EMPTY_ELEMENTDATA) {
            minCapacity= Math.max(DEFAULT_CAPACITY, minCapacity);
        }
        ensureExplicitCapacity(minCapacity);
    }
    /**
     * 私有方法：明确 ArrayList 的容量
     * @param minCapacity    指定的最小容量
     */
    private void ensureExplicitCapacity(int minCapacity) {
        // 将“修改统计数”+1，该变量主要是用来实现fail-fast机制的
        modCount++;
        // 防止溢出代码：确保指定的最小容量 > 数组缓冲区当前的长度
        if (minCapacity - elementData.length > 0)
            grow(minCapacity);
    }

    /**
     * 数组缓冲区最大存储容量
     * - 一些 VM 会在一个数组中存储某些数据--->为什么要减去 8 的原因
     * - 尝试分配这个最大存储容量，可能会导致 OutOfMemoryError(当该值 > VM 的限制时)
     */
    private static final int MAX_ARRAY_SIZE = Integer.MAX_VALUE - 8;

    /**
     * 私有方法：扩容，以确保 ArrayList 至少能存储 minCapacity 个元素
     * 扩容计算：newCapacity = oldCapacity + (oldCapacity >> 1);  扩充当前容量的1.5倍
     * @param minCapacity    指定的最小容量
     */
    private void grow(int minCapacity) {
        // 防止溢出代码
        int oldCapacity = elementData.length;
        // 运算符 >> 是带符号右移. 如 oldCapacity = 10,则 newCapacity = 10 + (10 >> 1) = 10 + 5 = 15
        int newCapacity = oldCapacity + (oldCapacity >> 1);
        if (newCapacity - minCapacity < 0)  // 若 newCapacity 依旧小于 minCapacity
            newCapacity = minCapacity;
        if (newCapacity - MAX_ARRAY_SIZE > 0)   // 若 newCapacity 大于最大存储容量，则进行大容量分配
            newCapacity = hugeCapacity(minCapacity);
        // minCapacity is usually close to size, so this is a win:
        elementData = Arrays.copyOf(elementData, newCapacity);
    }
    
 	/**
     * 私有方法：大容量分配，最大分配 Integer.MAX_VALUE
     * @param minCapacity
     */
    private static int hugeCapacity(int minCapacity) {
        if (minCapacity < 0) // overflow
            throw new OutOfMemoryError();
        return (minCapacity > MAX_ARRAY_SIZE) ?
                Integer.MAX_VALUE :
                MAX_ARRAY_SIZE;
    }


    /** 将数组容量缩小至元素数量 */
    public void trimToSize() {
        modCount++;
        if (size < elementData.length) {
            elementData = (size == 0)
              ? EMPTY_ELEMENTDATA
              : Arrays.copyOf(elementData, size);
        }
    }

```



### remove

```java
	/**
     * 移除指定位置的元素
     * index 之后的所有元素依次左移一位
     * @param index 指定位置
     * @return 被移除的元素
     * @throws IndexOutOfBoundsException
     */
    public E remove(int index) {
        rangeCheck(index);

        modCount++;
        E oldValue = elementData(index);
		//要移动的长度
        int numMoved = size - index - 1;
        if (numMoved > 0)
            System.arraycopy(elementData, index+1, elementData, index,
                    numMoved);
        // 将最后一个元素置空
        elementData[--size] = null;

        return oldValue;
    }

  	private void rangeCheck(int index) {
        if (index >= size)
            throw new IndexOutOfBoundsException(outOfBoundsMsg(index));
    }

    /**
     * 移除list中指定的第一个元素(符合条件索引最低的)
     * 如果list中不包含这个元素，这个list不会改变
     * 如果包含这个元素，index 之后的所有元素依次左移一位
     * @param o 这个list中要被移除的元素
     * @return
     */
    public boolean remove(Object o) {
        if (o == null) {
            for (int index = 0; index < size; index++)
                if (elementData[index] == null) {
                    fastRemove(index);
                    return true;
                }
        } else {
            for (int index = 0; index < size; index++)
                if (o.equals(elementData[index])) {
                    fastRemove(index);
                    return true;
                }
        }
        return false;
    }

    /**
     * 快速删除第 index 个元素
     * 和public E remove(int index)相比 :私有方法，跳过检查，不返回被删除的值
     * @param index 要删除的脚标
     */
    private void fastRemove(int index) {
        modCount++;
        int numMoved = size - index - 1;
        if (numMoved > 0)
            System.arraycopy(elementData, index+1, elementData, index,
                    numMoved);
        elementData[--size] = null; 
    }

    
```



### 遍历的坑

ArrayList 实现了 RandomAccess 接口（该接口是个标志性接口），表明它具有随机访问的能力。ArrayList 底层基于数组实现，所以它可在常数阶的时间内完成随机访问，效率很高。对 ArrayList 进行遍历时，一般情况下，我们喜欢使用 foreach 循环遍历，但这并不是推荐的遍历方式。ArrayList 具有随机访问的能力，如果在一些效率要求比较高的场景下，更推荐普通for循环

[增强for循环原理]:https://blog-1257031229.cos.ap-shanghai.myqcloud.com/%E5%A2%9E%E5%BC%BAfor%E5%BE%AA%E7%8E%AF%E5%8E%9F%E7%90%86.png
[增强for循环数组大小为2]:https://blog-1257031229.cos.ap-shanghai.myqcloud.com/%E5%A2%9E%E5%BC%BAfor%E5%BE%AA%E7%8E%AF%E6%95%B0%E7%BB%84%E5%A4%A7%E5%B0%8F%E4%B8%BA2.png
[增强for循环数组大小为3]:https://blog-1257031229.cos.ap-shanghai.myqcloud.com/%E5%A2%9E%E5%BC%BAfor%E5%BE%AA%E7%8E%AF%E6%95%B0%E7%BB%84%E5%A4%A7%E5%B0%8F%E4%B8%BA3.png
[普通for循环]:https://blog-1257031229.cos.ap-shanghai.myqcloud.com/%E6%99%AE%E9%80%9Afor%E5%BE%AA%E7%8E%AF.png
[迭代器删除]:https://blog-1257031229.cos.ap-shanghai.myqcloud.com/%E8%BF%AD%E4%BB%A3%E5%99%A8%E5%88%A0%E9%99%A4.png

1. 普通for循环 remove

![普通for循环]

**普通for循环remove时，如果有重复的，则会少删除很多，但不会抛出异常**

**所以从后往前遍历就OK**



2. foreach remove

![增强for循环数组大小为2]

![增强for循环数组大小为3]

**foreach remove时，如果不是remove的最后或倒数第二个元素时，会抛出ConcurrentModificationException异常**

![增强for循环原理]

**foreach语法糖其实编译成字节码后会被转成用迭代器遍历的方式，next()方法会判断modCount 是否等于 expectedModCount，而上一次list的remove方法会使modCount+1，以至于抛出ConcurrentModificationException异常**

**如果是remove的最后或倒数第二个元素时，hasNext()会直接返回false，结束循环**

3. 迭代器删除

![迭代器删除]

**迭代器删除不会抛出异常的原因是迭代器的remove方法会设置expectedModCount = modCount**









