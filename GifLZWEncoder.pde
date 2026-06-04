// LZW encoder for GIF - used by AnimatedGifEncoder.

class GifLZWEncoder {
  static final int EOF=-1,BITS=12,HSIZE=5003;
  int imgW,imgH; byte[] pixAry; int initCodeSize;
  int remaining,curPixel,n_bits,maxbits=BITS,maxcode,maxmaxcode=1<<BITS;
  int[] htab=new int[HSIZE],codetab=new int[HSIZE];
  int free_ent=0; boolean clear_flg=false;
  int g_init_bits,ClearCode,EOFCode,cur_accum=0,cur_bits=0;
  int[] masks={0x0000,0x0001,0x0003,0x0007,0x000F,0x001F,0x003F,0x007F,
               0x00FF,0x01FF,0x03FF,0x07FF,0x0FFF,0x1FFF,0x3FFF,0x7FFF,0xFFFF};
  int a_count; byte[] accum=new byte[256];

  GifLZWEncoder(int w,int h,byte[] pix,int depth){
    imgW=w;imgH=h;pixAry=pix;initCodeSize=Math.max(2,depth);
  }

  void encode(java.io.OutputStream os) throws java.io.IOException {
    os.write(initCodeSize);remaining=imgW*imgH;curPixel=0;
    compress(initCodeSize+1,os);os.write(0);
  }

  private void compress(int init_bits,java.io.OutputStream outs) throws java.io.IOException {
    g_init_bits=init_bits;clear_flg=false;n_bits=g_init_bits;maxcode=mc(n_bits);
    ClearCode=1<<(init_bits-1);EOFCode=ClearCode+1;free_ent=ClearCode+2;a_count=0;
    int ent=np(),hshift=0,fcode;
    for(fcode=HSIZE;fcode<65536;fcode*=2)++hshift;hshift=8-hshift;
    ch(HSIZE);output(ClearCode,outs);
    outer:while((fcode=np())!=EOF){
      int c=fcode;fcode=(c<<maxbits)+ent;int i=(c<<hshift)^ent;
      if(htab[i]==fcode){ent=codetab[i];continue;}
      else if(htab[i]>=0){int disp=HSIZE-i;if(i==0)disp=1;
        do{if((i-=disp)<0)i+=HSIZE;if(htab[i]==fcode){ent=codetab[i];continue outer;}}while(htab[i]>=0);}
      output(ent,outs);ent=c;
      if(free_ent<maxmaxcode){codetab[i]=free_ent++;htab[i]=fcode;}else cb(outs);
    }
    output(ent,outs);output(EOFCode,outs);
  }

  private void output(int code,java.io.OutputStream outs) throws java.io.IOException {
    cur_accum&=masks[cur_bits];cur_accum=(cur_bits>0)?cur_accum|(code<<cur_bits):code;cur_bits+=n_bits;
    while(cur_bits>=8){co((byte)(cur_accum&0xFF),outs);cur_accum>>=8;cur_bits-=8;}
    if(free_ent>maxcode||clear_flg){if(clear_flg){maxcode=mc(n_bits=g_init_bits);clear_flg=false;}else{++n_bits;maxcode=(n_bits==maxbits)?maxmaxcode:mc(n_bits);}}
    if(code==EOFCode){while(cur_bits>0){co((byte)(cur_accum&0xFF),outs);cur_accum>>=8;cur_bits-=8;}fc(outs);}
  }

  private void co(byte c,java.io.OutputStream o) throws java.io.IOException {accum[a_count++]=c;if(a_count>=254)fc(o);}
  private void fc(java.io.OutputStream o) throws java.io.IOException {if(a_count>0){o.write(a_count);o.write(accum,0,a_count);a_count=0;}}
  private void cb(java.io.OutputStream o) throws java.io.IOException {ch(HSIZE);free_ent=ClearCode+2;clear_flg=true;output(ClearCode,o);}
  private void ch(int h){for(int i=0;i<h;i++)htab[i]=-1;}
  private int mc(int n){return(1<<n)-1;}
  private int np(){if(remaining==0)return EOF;--remaining;return pixAry[curPixel++]&0xFF;}
}
