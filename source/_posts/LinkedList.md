---
title: LinkedList源码分析
author: kangshifu
top: false
cover: false
toc: true
mathjax: false
categories: Collection
tags:
  - Java
  - Collection
abbrlink: 1197454209
date: 2019-10-06 17:22:11
img:
coverImg:
password:
summary:
---


<!--more--> 



LinkedList 的继承体系较为复杂，继承自 AbstractSequentialList，同时又实现了 List 和 Deque 接口

AbstractSequentialList 提供了一套基于顺序访问的接口。通过继承此类，子类仅需实现部分代码即可拥有完整的一套访问某种序列表（比如链表）的接口。

另外，LinkedList 还实现了 Deque (double ended queue)，Deque 又继承自 Queue 接口。这样 LinkedList 就具备了队列的功能。

![LinkedList类图](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/LinkedList%E7%B1%BB%E5%9B%BE.png)



## Node

在`LinkedList`中，每一个元素都是`Node`存储，`Node`拥有一个存储值的`item`与一个前驱`prev`和一个后继`next`，如下：

```java
private static class Node<E> {
    E item;// 存储元素
    Node<E> next;// 指向上一个元素
    Node<E> prev;// 指向下一个元素
    Node(Node<E> prev, E element, Node<E> next) {
        this.item = element;
        this.next = next;
        this.prev = prev;
    }
}
```



## 成员变量

```java
transient int size = 0;//当前列表的元素个数

transient Node<E> first;// 第一个元素

transient Node<E> last;// 最后一个元素
```



## 构造函数

```java
//无参构造函数
public LinkedList() {}

public LinkedList(Collection<? extends E> c) {
    this();
    addAll(c);//将c中的元素都添加到此列表中
}

public boolean addAll(Collection<? extends E> c) {
    return addAll(size, c);//此时 size == 0
}


public boolean addAll(int index, Collection<? extends E> c) {
    // 检查index是否在[0,size]内，注意是闭区间 否则报异常
    checkPositionIndex(index);
    Object[] a = c.toArray();// 得到一个元素数组
    int numNew = a.length;// c中元素的数量
    if (numNew == 0)
        return false;// 没有元素，添加失败

    // 主要功能是找到第size个元素的前驱和后继。得到此元素需要分情况讨论。
    Node<E> pred, succ;// 前驱与后继
    if (index == size) {// 如果位置与当前的size相同
        succ = null;// 无后继
        pred = last;// 前驱为last，即第size个元素(最后一个元素)
    } else {// 若与size不同，即index位于[0, size)之间
        succ = node(index);// 后继为第index个元素
        pred = succ.prev;// 前驱为后继的前驱
    }
    // 开始逐个插入
    for (Object o : a) {
        @SuppressWarnings("unchecked") E e = (E) o;
        // 新建一个以pred为前驱、null为后继、值为e的节点
        Node<E> newNode = new Node<>(pred, e, null);
        if (pred == null)// 前驱为空，则此节点被当做列表的第一个节点
            first = newNode;
        else// 规避掉了NullPointerException，感觉又达到了目的，又实现了逻辑
            pred.next = newNode;// 不为空，则将前驱的后继改成当前节点
        pred = newNode;// 将前驱改成当前节点，以便后续添加c中其它的元素
    }
    // 至此，c中元素已添加到链表上，但链表中从size开始的那些元素还没有链接到列表上
    // 此时就需要利用到之前找出来的succ值，它是作为这个c的整体后继
    if (succ == null) {// 如果后继为空，说明无整体后继
        last = pred;// c的最后一个元素应当作为列表的尾元素
    } else {// 有整体后继
        pred.next = succ;// pred即c中的最后一个元素，其后继指向succ，即整体后继
        succ.prev = pred;// succ的前驱指向c中的最后一个元素
    }
    // 添加完毕，修改参数
    size += numNew;
    modCount++;
    return true;
}
```

## get

```java
public E get(int index) {
    checkElementIndex(index);
    return node(index).item;// 获取节点，并返回节点中的元素值
}
```

```java
//返回序号为index的元素节点
Node<E> node(int index) {
    // 视其与中值得差距，觉得从前遍历还是从后遍历。
    if (index < (size >> 1)) {
        Node<E> x = first;
        // 循环index次 迭代到所需要的元素
        for (int i = 0; i < index; i++)
            x = x.next;
        return x;
    } else {
        Node<E> x = last;
        // 循环size-1-index次
        for (int i = size - 1; i > index; i--)
            x = x.prev;
        return x;
    }
}
```

## set

```java
public E set(int index, E element) {
     checkElementIndex(index);
     Node<E> x = node(index);// 获取到需要修改元素的节点
     E oldVal = x.item;// 保存之前的值
     x.item = element;// 修改
     return oldVal;// 返回修改前的值
```



## link

```java
//将e链接成列表的第一个元素
private void linkFirst(E e) {
    final Node<E> f = first;
    final Node<E> newNode = new Node<>(null, e, f);
    first = newNode;
    if (f == null)// 若f为空，则表明列表中还没有元素
        last = newNode;// last也应该指向newNode
    else
        f.prev = newNode;// 否则，前first的前驱指向newNode
    size++;
    modCount++;
}

//将e链接为最后一个元素
void linkLast(E e) {
    final Node<E> l = last;
    final Node<E> newNode = new Node<>(l, e, null);
    last = newNode;
    if (l == null)// 最后一个节点为空，说明列表中无元素
        first = newNode;// first同样指向此节点
    else
        l.next = newNode;// 否则，前last的后继指向当前节点
    size++;
    modCount++;
}

//将e链接到节点succ前
void linkBefore(E e, Node<E> succ) {
    final Node<E> pred = succ.prev; 
    final Node<E> newNode = new Node<>(pred, e, succ);
    succ.prev = newNode;
    if (pred == null)// pred为空，说明此时succ为首节点
        first = newNode;// 指向当前节点
    else
        pred.next = newNode;// 否则，将succ之前的前驱的后继指向当前节点
    size++;
    modCount++;
}
```

## unLink

```java
//删除首节点
private E unlinkFirst(Node<E> f) {
    final E element = f.item;// 取出首节点中的元素
    final Node<E> next = f.next;// 取出首节点中的后继
    f.item = null;
    f.next = null; // 方便 GC 回收
    first = next;// first指向前first的后继，也就是列表中的2号位
    if (next == null)// 如果此时2号位为空，那么列表中此时已无节点
        last = null;// last指向null
    else
        next.prev = null;// 首节点无前驱
    size--;
    modCount++;
    return element;// 返回首节点保存的元素值
}

//删除尾节点
private E unlinkLast(Node<E> l) {
    final E element = l.item;// 取出尾节点中的元素
    final Node<E> prev = l.prev;// 取出尾节点中的前驱
    l.item = null;
    l.prev = null; // help GC
    last = prev;// last指向前last的前驱，也就是列表中的倒数2号位
    if (prev == null)// 如果此时倒数2号位为空，那么列表中已无节点
        first = null;// first指向null
    else
        prev.next = null;// 尾节点无后继
    size--;
    modCount++;
    return element;// 返回尾节点保存的元素值
}

//删除某个非空节点
 E unlink(Node<E> x) {
        final E element = x.item;
        final Node<E> next = x.next;
        final Node<E> prev = x.prev;

     	// 前驱为null，说明x为首节点
        if (prev == null) {
            first = next;
        } else {
            prev.next = next;
            x.prev = null;
        }

        if (next == null) {
            last = prev;
        } else {
            next.prev = prev;
            x.next = null;
        }

        x.item = null;// help GC
        size--;
        modCount++;
        return element;
    }
```





## add

```java
 public boolean add(E e) {
     linkLast(e);
     return true;
 }
 
 public void add(int index, E element) {
     checkPositionIndex(index);
     if (index == size)
         linkLast(element);
     else
         linkBefore(element, node(index));
 }
 public void addFirst(E e) {
     linkFirst(e);
 }
 public void addLast(E e) {
     linkLast(e);
 }
```



## remove

```java
public E removeFirst() {
    final Node<E> f = first;
    if (f == null)
        throw new NoSuchElementException();
    return unlinkFirst(f);
}

public E removeLast() {
    final Node<E> l = last;
    if (l == null)
        throw new NoSuchElementException();
    return unlinkLast(l);
}

// 遍历列表中所有的节点，找到相同的元素，然后删除它
//跟indexof类似
public boolean remove(Object o) {
    if (o == null) {
        for (Node<E> x = first; x != null; x = x.next) {
            if (x.item == null) {
                unlink(x);
                return true;
            }
        }
    } else {
        for (Node<E> x = first; x != null; x = x.next) {
            if (o.equals(x.item)) {
                unlink(x);
                return true;
            }
        }
    }
    return false;
}

public E remove(int index) {
    checkElementIndex(index);
    return unlink(node(index));
}
```

## indexOf

```java
public int indexOf(Object o) {
    int index = 0;
    if (o == null) {// null时分开处理
        for (Node<E> x = first; x != null; x = x.next) {
            if (x.item == null)// 说明找到
                return index;// 返回下标
            index++;
        }
    } else {
        for (Node<E> x = first; x != null; x = x.next) {
            if (o.equals(x.item))// 说明找到
                return index;// 返回下标
            index++;
        }
    }
    return -1;// 未找到，返回-1
}
```



## foreach

通常情况下，我们会使用 foreach 遍历 LinkedList，而 foreach 最终转换成迭代器形式。所以分析 LinkedList 的遍历的核心就是它的迭代器实现，相关代码如下：

```java
public ListIterator<E> listIterator(int index) {
    checkPositionIndex(index);
    return new ListItr(index);
}

private class ListItr implements ListIterator<E> {
    private Node<E> lastReturned;
    private Node<E> next;
    private int nextIndex;
    private int expectedModCount = modCount;

    /** 构造方法将 next 引用指向指定位置的节点 */
    ListItr(int index) {
        next = (index == size) ? null : node(index);
        nextIndex = index;
    }

    public boolean hasNext() {
        return nextIndex < size;
    }

    public E next() {
        checkForComodification();
        if (!hasNext())
            throw new NoSuchElementException();

        lastReturned = next;
        next = next.next;    // 调用 next 方法后，next 引用都会指向他的后继节点
        nextIndex++;
        return lastReturned.item;
    }
}
```



