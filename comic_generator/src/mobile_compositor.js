const clamp=(value,min,max,fallback)=>Number.isFinite(Number(value))?Math.max(min,Math.min(max,Number(value))):fallback;
export function mobileSettings(value={}){return {zoom:clamp(value?.zoom,1,3,1),x:clamp(value?.x,0,1,.5),y:clamp(value?.y,0,1,.5),textScale:clamp(value?.textScale,.8,1.8,1),speechY:clamp(value?.speechY,.1,.75,.2)};}
export function cropRectangle(sourceWidth,sourceHeight,width,height,value){const settings=mobileSettings(value),ratio=width/height;let w=sourceWidth,h=w/ratio;if(h>sourceHeight){h=sourceHeight;w=h*ratio;}w/=settings.zoom;h/=settings.zoom;return {x:(sourceWidth-w)*settings.x,y:(sourceHeight-h)*settings.y,width:w,height:h};}
export function wrapText(ctx,text,maxWidth){const lines=[];let line='';for(const word of String(text).split(/\s+/)){if(!word)continue;const next=line?line+' '+word:word;if(ctx.measureText(next).width>maxWidth&&line){lines.push(line);line='';}if(ctx.measureText(word).width>maxWidth){for(const character of word){const nextPart=line+character;if(ctx.measureText(nextPart).width>maxWidth&&line){lines.push(line);line=character;}else line=nextPart;}}else line=line?line+' '+word:word;}if(line)lines.push(line);return lines;}
function textPanel(ctx,text,{width,height,font,y,bubble=false,maxHeight=height*.75,bottomLimit=height*.965}){
 const maxWidth=width*.84,padding=width*.035,requestedSize=Number(font.match(/([\d.]+)px/)[1]);let fontSize=requestedSize,lines,lineHeight,boxHeight;
 for(let attempt=0;attempt<100;attempt++){
  ctx.font=font.replace(/[\d.]+px/,fontSize+'px');lines=wrapText(ctx,text,maxWidth-padding*2);lineHeight=fontSize*1.24;boxHeight=lines.length*lineHeight+padding*2;
  if(boxHeight<=maxHeight)break;fontSize*=.94;
 }
 const boxWidth=Math.min(maxWidth,Math.max(width*.18,...lines.map(line=>ctx.measureText(line).width+padding*2)));
 const top=Math.max(height*.035,Math.min(bottomLimit-boxHeight,y*height-boxHeight/2)),left=(width-boxWidth)/2;
 ctx.fillStyle=bubble?'#fff6dc':'rgba(0,0,0,.86)';ctx.strokeStyle=bubble?'#111':'#b8c3c9';ctx.lineWidth=Math.max(2,width/240);ctx.beginPath();ctx.roundRect(left,top,boxWidth,boxHeight,bubble?width*.055:width*.012);ctx.fill();ctx.stroke();
 if(bubble){ctx.beginPath();ctx.moveTo(width*.46,top+boxHeight-1);ctx.lineTo(width*.42,Math.min(height*.98,top+boxHeight+Math.min(width*.04,height*.02)));ctx.lineTo(width*.54,top+boxHeight-1);ctx.fill();ctx.stroke();}
 ctx.fillStyle=bubble?'#171718':'#fff6e2';ctx.textAlign='center';ctx.textBaseline='middle';lines.forEach((line,index)=>ctx.fillText(line,width/2,top+padding+(index+.5)*lineHeight));
 return {left,top,width:boxWidth,height:boxHeight,lines,fontSize,requestedSize};
}
export function composeMobile(ctx,source,{width,height,settings,speech='',caption='',title='',alarm='',black=0}){
 const framing=mobileSettings(settings),crop=cropRectangle(source.width,source.height,width,height,framing);ctx.save();ctx.clearRect(0,0,width,height);ctx.drawImage(source,crop.x,crop.y,crop.width,crop.height,0,0,width,height);ctx.globalAlpha=1-Math.max(0,Math.min(1,black));const panels={};
 if(speech)panels.speech=textPanel(ctx,speech,{width,height,font:'700 '+(Math.min(width,height)*.053*framing.textScale)+'px "Comic Neue", sans-serif',y:framing.speechY,bubble:true,maxHeight:height*.43,bottomLimit:caption?height*.61:height*.93});
 if(caption)panels.caption=textPanel(ctx,caption,{width,height,font:'italic '+(Math.min(width,height)*.046*framing.textScale)+'px Georgia, serif',y:.89,maxHeight:height*.3});
 if(alarm){ctx.font='900 '+(width*.027)+'px sans-serif';ctx.fillStyle='#ff5348';ctx.textAlign='center';ctx.fillText(alarm,width/2,height*.045);}
 ctx.globalAlpha=1;if(title)panels.title=textPanel(ctx,title,{width,height,font:'700 '+(Math.min(width,height)*.06*framing.textScale)+'px "Comic Neue", sans-serif',y:.5});ctx.restore();return {crop,panels};
}
