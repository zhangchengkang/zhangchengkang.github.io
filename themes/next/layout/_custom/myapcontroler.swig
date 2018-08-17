<script src="/js/src/Aplayer-Controler.js"></script>
<div id="AP-controler"></div>
<script type="text/javascript">

var ap = new APlayer({
	    element: document.getElementById('player1'),                       // （可选）播放器袖珍风格
	    narrow: false,                                                     // （可选）自动播放，移动端浏览器暂不支持此功能
	    autoplay: true,                                                    // （可选）曲目循环类型，有'random'（随机），'single'(单曲)，'circulation'(循环)，'order'(列表)，默认'circulation'
	    showlrc: 0,                                                        // （可选）歌词显示配置项，可选项1、2、3
	    mutex: true,                                                       // （可选）该选项开启时，同页有其它aplayer播放则该播放器暂停
	    theme: '#8B008B',                                                  // （可选）播放器风格色彩设置，默#b7daff
	    mode: 'random',                                                    // （可选）曲目循环类型，有'random'（随机），'single'(单曲)，'circulation'(循环)，'order'(列表)，默认'circulation'
	    preload: 'metadata',                                               // （可选）音乐文件预载入模式，可选项'none'、'metadata'、'auto'，默'auto'
	    listmaxheight: '250px',                                            // （可选）该播放列表最大长度
	    music: [
	    {
	    	title: '七月上',                                         
	        author: 'Jam',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E4%B8%83%E6%9C%88%E4%B8%8A%20-%20Jam.mp3', 
	        pic: 'http://p1.music.126.net/9kZl6NRj3HxmQQ8DqTjZ4Q==/17729624997966923.jpg?param=130y130'
	    },
	    {
	    	title: '匆匆 ',                                         
	        author: '二珂.',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E5%8C%86%E5%8C%86%20-%20%E8%B5%B5%E9%92%B6%2C%E4%BA%8C%E7%8F%82.mp3', 
	        pic: 'http://p1.music.126.net/8GXkHa3eq63ikMMZ2nY8Gw==/109951163249852201.jpg?param=130y130'
	    },{
	    	title: '匆匆那年',                                         
	        author: '王菲',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E5%8C%86%E5%8C%86%E9%82%A3%E5%B9%B4%20-%20%E7%8E%8B%E8%8F%B2.mp3', 
	        pic: 'http://p1.music.126.net/yXyeAl-7m0tqfx4AX7BDSQ==/2542070884980240.jpg?param=130y130'
	    },{
	    	title: '后来我们会怎样',                                         
	        author: '刘惜君',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E5%90%8E%E6%9D%A5%E6%88%91%E4%BB%AC%E4%BC%9A%E6%80%8E%E6%A0%B7%20-%20%E5%88%98%E6%83%9C%E5%90%9B.mp3', 
	        pic: 'http://p1.music.126.net/C0nqK9yq5_LRHbQ6EqfzNg==/3384296793240085.jpg?param=130y130'
	    },{
	    	title: '小幸运',                                         
	        author: '田馥甄',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E5%B0%8F%E5%B9%B8%E8%BF%90%20-%20%E7%94%B0%E9%A6%A5%E7%94%84.mp3', 
	        pic: 'http://p4.music.126.net/oTF9i5fY79GdAwbLQ7xMCQ==/109951163272573333.jpg?param=50y50'
	    },{
	    	title: '岁月神偷',                                         
	        author: '金玟岐',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E5%B2%81%E6%9C%88%E7%A5%9E%E5%81%B7%20-%20%E9%87%91%E7%8E%9F%E5%B2%90.mp3', 
	        pic: 'http://p1.music.126.net/RTuj3aTIZrR-v0-W_dD2VQ==/19080924788792622.jpg?param=50y50'
	    },{
	    	title: '愿得一人心',                                         
	        author: '谭艳',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E6%84%BF%E5%BE%97%E4%B8%80%E4%BA%BA%E5%BF%83%20-%20%E8%B0%AD%E8%89%B3.mp3', 
	        pic: 'http://p4.music.126.net/1N8HiCwgY7DqO-wILpJTeQ==/3438172872014843.jpg?param=50y50'
	    },{
	    	title: '我们不是说好了吗 ',                                         
	        author: '白百何',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E6%88%91%E4%BB%AC%E4%B8%8D%E6%98%AF%E8%AF%B4%E5%A5%BD%E4%BA%86%E5%90%97%20-%20%E5%BD%AD%E4%BA%8E%E6%99%8F%2C%E7%99%BD%E7%99%BE%E4%BD%95.mp3', 
	        pic: 'http://p1.music.126.net/Wc7s_rVkVHTKrMRu4xFNzQ==/2315571488119029.jpg?param=130y130'
	    },{
	    	title: '我们都被忘了',                                         
	        author: '谢安琪',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E6%88%91%E4%BB%AC%E9%83%BD%E8%A2%AB%E5%BF%98%E4%BA%86%20-%20%E8%B0%A2%E5%AE%89%E7%90%AA.mp3', 
	        pic: 'http://p3.music.126.net/fBDRSoH46yYAldgmUAu7hw==/18684001092518241.jpg?param=50y50'
	    },{
	    	title: '泡沫',                                         
	        author: '邓紫棋',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E6%B3%A1%E6%B2%AB%20-%20G.E.M.%E9%82%93%E7%B4%AB%E6%A3%8B.mp3', 
	        pic: 'http://p3.music.126.net/P8VwgDjdLDN4spkwIv8QXg==/18722483999690981.jpg?param=50y50'
	    },{
	    	title: '漂洋过海来看你',                                         
	        author: '李宗盛',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E6%BC%82%E6%B4%8B%E8%BF%87%E6%B5%B7%E6%9D%A5%E7%9C%8B%E4%BD%A0%C2%A0%5B20170527-%E5%B9%B4%E5%BA%A6%E7%AC%AC4%E6%AC%A1%E6%AD%A3%E5%BC%8F%E6%B4%BB%E5%8A%A8%5D%EF%BC%88Cover%20%E6%9D%8E%E5%AE%97%E7%9B%9B%20%EF%BC%8F%20%E5%A8%83%E5%A8%83%EF%BC%89%20-%20%E5%AD%A6%E5%94%B1%E5%9B%A2.mp3', 
	        pic: 'http://p1.music.126.net/IXm8On-EZt82SnBz00GQ3Q==/109951162940064301.jpg?param=130y130'
	    },{
	    	title: '纸短情长',                                         
	        author: '烟把儿',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E7%BA%B8%E7%9F%AD%E6%83%85%E9%95%BF%EF%BC%88%E5%AE%8C%E6%95%B4%E7%89%88%EF%BC%89%20-%20%E7%83%9F%E6%8A%8A%E5%84%BF.mp3', 
	        pic: 'http://p1.music.126.net/tbZaE-DjL_BkemynFlL1cQ==/109951163052534918.jpg?param=130y130'
	    },{
	    	title: '美丽世界的孤儿',                                         
	        author: '汪峰',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E7%BE%8E%E4%B8%BD%E4%B8%96%E7%95%8C%E7%9A%84%E5%AD%A4%E5%84%BF%20-%20%E6%B1%AA%E5%B3%B0.ncm', 
	        pic: 'http://p3.music.126.net/pP2sbfkvd6nsmdbmFTIEJQ==/109951163116154677.jpg?param=50y50'
	    },{
	    	title: '致青春',                                         
	        author: '王菲',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E8%87%B4%E9%9D%92%E6%98%A5%20-%20%E7%8E%8B%E8%8F%B2.mp3', 
	        pic: 'http://p3.music.126.net/WjDAZ9C8whAB6yfE_sfIFw==/109951163244980773.jpg?param=50y50'
	    },{
	    	title: '说散就散',                                         
	        author: '袁娅维',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E8%AF%B4%E6%95%A3%E5%B0%B1%E6%95%A3%20-%20%E8%A2%81%E5%A8%85%E7%BB%B4.ncm', 
	        pic: 'http://p4.music.126.net/zsRaHUdZO7LQ0hTX5ptqGg==/109951163102064502.jpg?param=50y50'
	    },{
	    	title: '走在冷风中',                                         
	        author: '二珂',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E8%B5%B0%E5%9C%A8%E5%86%B7%E9%A3%8E%E4%B8%AD%20-%20%E4%BA%8C%E7%8F%82.mp3', 
	        pic: 'http://p1.music.126.net/iAaRt_l_ussYqkLVuDEpqg==/2931298001578529.jpg?param=130y130'
	    },{
	    	title: '追光者',                                         
	        author: '岑宁儿',                        
	        url: 'https://zckdmp3-1257031229.cos.ap-guangzhou.myqcloud.com/%E8%BF%BD%E5%85%89%E8%80%85%20-%20%E5%B2%91%E5%AE%81%E5%84%BF.mp3', 
	        pic: 'http://p4.music.126.net/1N8HiCwgY7DqO-wILpJTeQ==/3438172872014843.jpg?param=50y50'
	    },
	    ]
});
var myapc=new APlayer_Controler({
		APC_dom:$('#AP-controler'),
		aplayer:ap, //此为绑定的aplayer对象
		attach_right:true,
		position:{top:'150px',bottom:''},
		fixed:true,
		btn_width:100,
		btn_height:120,
		img_src:['http://oty1v077k.bkt.clouddn.com/bukagirl.jpg',
				'http://oty1v077k.bkt.clouddn.com/jumpgirl.jpg',
				'http://oty1v077k.bkt.clouddn.com/pentigirl.jpg',
				'http://oty1v077k.bkt.clouddn.com/%E8%90%8C1.gif'],
		img_style:{repeat:'no-repeat',position:'center',size:'contain'},
		ctrls_color:'rgba(173,255,47,0.8)',
		ctrls_hover_color:'rgba(255,140,0,0.7)',
		tips_on:true,
		tips_width:140,
		tips_height:25,
		tips_color:'rgba(255,255,255,0.6)',
		tips_content:{},
		timeout:30
	});
</script>
You can't see this