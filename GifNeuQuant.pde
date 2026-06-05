// NeuQuant neural-net colour quantizer - used by AnimatedGifEncoder.
// Copyright (c) 1994 Anthony Dekker, ported to Java by Kevin Weiner.

class GifNeuQuant {
  static final int netsize=256,prime1=499,prime2=491,prime3=487,prime4=503;
  static final int minpicbytes=3*prime4,maxnetpos=netsize-1,netbiasshift=4,ncycles=100;
  static final int intbiasshift=16,intbias=1<<intbiasshift,gammashift=10,gamma=1<<gammashift;
  static final int betashift=10,beta=intbias>>betashift,betagamma=intbias<<(gammashift-betashift);
  static final int initrad=netsize>>3,radiusbiasshift=6,radiusbias=1<<radiusbiasshift;
  static final int initradius=initrad*radiusbias,radiusdec=30;
  static final int alphabiasshift=10,initalpha=1<<alphabiasshift;
  static final int radbiasshift=8,radbias=1<<radbiasshift;
  static final int alpharadbshift=alphabiasshift+radbiasshift,alpharadbias=1<<alpharadbshift;
  int alphadec;
  byte[] thepicture; int lengthcount,samplefac;
  int[][] network=new int[netsize][4];
  int[] netindex=new int[256],bias=new int[netsize],freq=new int[netsize],radpower=new int[initrad];

  GifNeuQuant(byte[] pic,int len,int sample){
    thepicture=pic;lengthcount=len;samplefac=sample;
    for(int i=0;i<netsize;i++){int v=(i<<(netbiasshift+8))/netsize;network[i][0]=network[i][1]=network[i][2]=v;freq[i]=intbias/netsize;}
  }

  byte[] process(){learn();unbiasnet();inxbuild();return colorMap();}

  byte[] colorMap(){
    byte[] map=new byte[3*netsize]; int[] idx=new int[netsize];
    for(int i=0;i<netsize;i++)idx[network[i][3]]=i;
    int k=0;for(int i=0;i<netsize;i++){int j=idx[i];map[k++]=(byte)network[j][0];map[k++]=(byte)network[j][1];map[k++]=(byte)network[j][2];}
    return map;
  }

  void inxbuild(){
    int prev=0,start=0;
    for(int i=0;i<netsize;i++){
      int[]p=network[i];int sp=i,sv=p[1];
      for(int j=i+1;j<netsize;j++)if(network[j][1]<sv){sp=j;sv=network[j][1];}
      int[]q=network[sp];
      if(i!=sp){int t;t=q[0];q[0]=p[0];p[0]=t;t=q[1];q[1]=p[1];p[1]=t;t=q[2];q[2]=p[2];p[2]=t;t=q[3];q[3]=p[3];p[3]=t;}
      if(sv!=prev){netindex[prev]=(start+i)>>1;for(int j=prev+1;j<sv;j++)netindex[j]=i;prev=sv;start=i;}
    }
    netindex[prev]=(start+maxnetpos)>>1;for(int j=prev+1;j<256;j++)netindex[j]=maxnetpos;
  }

  int map(int b,int g,int r){
    int best=-1,bestd=1000,i=netindex[g],j=i-1;
    while(i<netsize||j>=0){
      if(i<netsize){int[]p=network[i];int d=p[1]-g;if(d>=bestd)i=netsize;else{i++;if(d<0)d=-d;int a=p[0]-b;if(a<0)a=-a;d+=a;if(d<bestd){a=p[2]-r;if(a<0)a=-a;d+=a;if(d<bestd){bestd=d;best=p[3];}}}}
      if(j>=0){int[]p=network[j];int d=g-p[1];if(d>=bestd)j=-1;else{j--;if(d<0)d=-d;int a=p[0]-b;if(a<0)a=-a;d+=a;if(d<bestd){a=p[2]-r;if(a<0)a=-a;d+=a;if(d<bestd){bestd=d;best=p[3];}}}}}
    return best;
  }

  void unbiasnet(){for(int i=0;i<netsize;i++){network[i][0]>>=netbiasshift;network[i][1]>>=netbiasshift;network[i][2]>>=netbiasshift;network[i][3]=i;}}

  void altersingle(int a,int i,int b,int g,int r){int[]n=network[i];n[0]-=(a*(n[0]-b))/initalpha;n[1]-=(a*(n[1]-g))/initalpha;n[2]-=(a*(n[2]-r))/initalpha;}

  void alterneigh(int rad,int i,int b,int g,int r){
    int lo=i-rad;if(lo<-1)lo=-1;int hi=i+rad;if(hi>netsize)hi=netsize;
    int j=i+1,k=i-1,m=1;
    while(j<hi||k>lo){int a=radpower[m++];
      if(j<hi){int[]p=network[j++];p[0]-=(a*(p[0]-b))/alpharadbias;p[1]-=(a*(p[1]-g))/alpharadbias;p[2]-=(a*(p[2]-r))/alpharadbias;}
      if(k>lo){int[]p=network[k--];p[0]-=(a*(p[0]-b))/alpharadbias;p[1]-=(a*(p[1]-g))/alpharadbias;p[2]-=(a*(p[2]-r))/alpharadbias;}}
  }

  int contest(int b,int g,int r){
    int bestd=~(1<<31),bestbd=bestd,bestp=-1,bestbp=-1;
    for(int i=0;i<netsize;i++){int[]n=network[i];int d=n[0]-b;if(d<0)d=-d;int a=n[1]-g;if(a<0)a=-a;d+=a;a=n[2]-r;if(a<0)a=-a;d+=a;
      if(d<bestd){bestd=d;bestp=i;}int bd=d-((bias[i])>>(intbiasshift-netbiasshift));if(bd<bestbd){bestbd=bd;bestbp=i;}
      int bf=freq[i]>>betashift;freq[i]-=bf;bias[i]+=bf<<gammashift;}
    freq[bestp]+=beta;bias[bestp]-=betagamma;return bestbp;
  }

  void learn(){
    if(lengthcount<minpicbytes)samplefac=1;
    alphadec=30+((samplefac-1)/3);
    int pix=0,lim=lengthcount,sp=lengthcount/(3*samplefac),delta=Math.max(1,sp/ncycles);
    int alpha=initalpha,radius=initradius,rad=radius>>radiusbiasshift;
    if(rad<=1)rad=0;for(int i=0;i<rad;i++)radpower[i]=alpha*(((rad*rad-i*i)*radbias)/(rad*rad));
    int step;
    if(lengthcount<minpicbytes)step=3;
    else if((lengthcount%prime1)!=0)step=3*prime1;
    else if((lengthcount%prime2)!=0)step=3*prime2;
    else if((lengthcount%prime3)!=0)step=3*prime3;
    else step=3*prime4;
    for(int i=0;i<sp;i++){
      int b=(thepicture[pix]&0xFF)<<netbiasshift,g=(thepicture[pix+1]&0xFF)<<netbiasshift,r=(thepicture[pix+2]&0xFF)<<netbiasshift;
      int j=contest(b,g,r);altersingle(alpha,j,b,g,r);if(rad!=0)alterneigh(rad,j,b,g,r);
      pix+=step;if(pix>=lim)pix-=lengthcount;
      if((i+1)%delta==0){alpha-=alpha/alphadec;radius-=radius/radiusdec;rad=radius>>radiusbiasshift;if(rad<=1)rad=0;for(j=0;j<rad;j++)radpower[j]=alpha*(((rad*rad-j*j)*radbias)/(rad*rad));}
    }
  }
}
