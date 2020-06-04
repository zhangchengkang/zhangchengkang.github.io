---
title: SpringBoot过滤器&拦截器
author: kangshifu
top: false
cover: true
toc: true
mathjax: false
categories: SpringBoot
tags:
  - Java
  - SpringBoot
abbrlink: 4013045820
date: 2020-06-01 21:36:05
img:
coverImg:
password:
summary:
---

<!--more-->  





## 拦截器与过滤器的区别

1. 过滤器和拦截器触发时机和地点不一样，过滤器是在请求进入容器后，但请求进入servlet之前进行预处理的。请求结束返回也是，是在servlet处理完后，返回给前端之前。

   ![过滤器拦截器与容器的关系](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/springMVC/%E8%BF%87%E6%BB%A4%E5%99%A8%E6%8B%A6%E6%88%AA%E5%99%A8%E4%B8%8E%E5%AE%B9%E5%99%A8%E7%9A%84%E5%85%B3%E7%B3%BB.png)

2. - 拦截器可以获取IOC容器中的各个bean，而过滤器就不行，因为拦截器是spring提供并管理的，spring的功能可以被拦截器使用，在拦截器里注入一个service，可以调用业务逻辑。
   - 过滤器是JavaEE标准，只需依赖servlet api ，不需要依赖spring。

    - 其中第2步，SpringMVC的机制是由DispaterServlet来分发请求给不同的Controller，其实这一步是在Servlet的service()方法中执行的

   ![过滤器拦截器运行顺序](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/springMVC/%E8%BF%87%E6%BB%A4%E5%99%A8%E6%8B%A6%E6%88%AA%E5%99%A8%E8%BF%90%E8%A1%8C%E9%A1%BA%E5%BA%8F.png)

3. 过滤器的实现基于回调函数。而拦截器的实现基于反射、代理。

4. - 如果是非spring项目，那么拦截器不能用，只能使用过滤器。

   - 如果是处理controller前后，既可以使用拦截器也可以使用过滤器。

   - 如果是处理dispaterServlet前后，只能使用过滤器。

## spring boot 使用过滤器Filter

两种方式：

1. 使用spring boot提供的FilterRegistrationBean注册Filter

2. 使用原生servlet注解(@WebFilter)定义Filter

   两种方式的本质都是一样的，都是去FilterRegistrationBean注册自定义Filter

### @WebFilter 

```java
@Component
@WebFilter(urlPatterns = "/api/*", filterName = "myFilter")
public class MyFilter implements Filter {
    @Override
    public void init(FilterConfig filterConfig) throws ServletException {

    }
    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        System.out.println("MyFilter");
    }
    @Override
    public void destroy() {

    }
}
```



### FilterRegistrationBean

```java
public class MyFilter implements Filter {
    @Override
    public void init(FilterConfig filterConfig) throws ServletException {

    }
    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        // do something 处理request 或response
        System.out.println("MyFilter");
        // 调用filter链中的下一个filter
        filterChain.doFilter(servletRequest,servletResponse);
    }
    @Override
    public void destroy() {

    }
}


@Configuration
public class FilterConfig {

    @Bean
    public FilterRegistrationBean registrationBean() {
        FilterRegistrationBean registration = new FilterRegistrationBean(new MyFilter());
        registration.addUrlPatterns("/*");
        registration.setName("myFilter1");
		registration.setOrder(1);//执行顺序
        return registration;
    }
    
        @Bean
    public FilterRegistrationBean registrationBean() {
        FilterRegistrationBean registration = new FilterRegistrationBean(new MyFilter());
        registration.addUrlPatterns("/*");
        registration.setName("myFilter2");
		registration.setOrder(2);//执行顺序
        return registration;
    }
}
```



## spring boot 使用拦截器



```javascript
//定义拦截器
public class MyInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        System.out.println("preHandle");
        return true;
    }

    @Override
    public void postHandle(HttpServletRequest request, HttpServletResponse response, Object handler, @Nullable ModelAndView modelAndView) throws Exception {
        System.out.println("postHandle");
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, @Nullable Exception ex) throws Exception {
        System.out.println("afterCompletion");
    }
}
```

```java
//配置拦截器
@Configuration
public class MvcConfiguration implements WebMvcConfigurer {
	@Autowired
    private MyInterceptor myInterceptor;
    
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
         registry.addInterceptor(myInterceptor)
                .addPathPatterns("/**")
                .excludePathPatterns( "/n/**");
    }
}
```

```java
/** WebMvcConfigurer常用的方法 **/
/** 解决跨域问题 **/
public void addCorsMappings(CorsRegistry registry) ;

/** 添加拦截器 **/
void addInterceptors(InterceptorRegistry registry);

/** 这里配置视图解析器 **/
void configureViewResolvers(ViewResolverRegistry registry);

/** 配置内容裁决的一些选项 **/
void configureContentNegotiation(ContentNegotiationConfigurer configurer);

/** 视图跳转控制器 **/
void addViewControllers(ViewControllerRegistry registry);

/** 静态资源处理 **/
void addResourceHandlers(ResourceHandlerRegistry registry);

/** 默认静态资源处理器 **/
void configureDefaultServletHandling(DefaultServletHandlerConfigurer configurer);
```











