//+------------------------------------------------------------------+
//|                                                          PSO.mq4 |
//|                                                              Jon |
//|                                                               -- |
//+------------------------------------------------------------------+
#property copyright "Jon"
#property link      "--"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
struct conf
  {
   double            divisorKeltber;
   double            divRsi;
   double            zonaOSC;
   double            dmi;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct best  {
   conf              config;
   int               magicNumber;
   double            heuristica;
  };

struct particle
  {
   int               magicNumber;
   int               magicNumber2;
   conf              confActual;
   conf              confPrevia;
   best              localBest;
   int               magicNumber_localBest;
   int               cantOperaciones;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


extern int    number_particles=50;
extern double c2 = 0.99; //Social Component
extern double c1 = 0.0; //Nostalgy Component
extern double w=0.0; //Inertia
extern int max_operaciones = 10; //Cantidad op. x ciclo
extern string asd="-------------------------------------";
extern double coefGanadoras=1.0; //Coeficiente Ganadoras ~ (0,1)
extern double coefPerdedoras=1.0; //Coeficiente Perdedor ~ (0,1)
extern double coefTiempo=1.0; //Coeficiente Tiempo ~ (0,1)
extern int    minutosMinimo=20; //Minutos promedio a tender 
extern int pips_tp = 100; // Pips - Takeprofit
extern int pips_sl = 200; // Pips - Stop Loss
datetime time0;

int global_minutes=15;
best globalbest;
//int max_operaciones=10;
int max_opened_orders=1;
particle set_particulas[1000];
int pso_handler;
string filename="pso_results.csv";
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if(coefGanadoras>1 || coefPerdedoras>1 || coefTiempo>1){Print("Coeficientes deben estar entre 0 y 1"); return(INIT_FAILED); }
   if(coefGanadoras+coefPerdedoras>2){ Print("Coeficiente Ganador + Coeficiente Perdedor > 2 "); return(INIT_FAILED);}
   time0=Time[0];
   ArrayResize(set_particulas,1000);
   globalbest.magicNumber=1234;
   for(int i=0;i<=number_particles-1;i++)
     {
      initialize_particle(set_particulas[i], 10+i);
     }
   initialize_global();  
   if (FileIsExist(filename)){FileDelete(filename);}
   pso_handler = FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV,','); //open el file a memoria
      if(pso_handler<0)
     {
      Print("Failed to open the file by the absolute path");
      Print("Error code ",GetLastError());
     }
   FileWrite(pso_handler, "Particula", "Heuristica/Aptitud", "Op. Ganadas", "Op. Perdidas", "Tiempo", "Magic Number", "Config RSI", "Config Keltner", "Config OSC");
   FileFlush(pso_handler);
   FileClose(pso_handler);
   //FileWrite(pso_handler,nroParticula,heuristica,ganadas, perdidas, tiempo,Magic Number ,Rsi, Keltber, zonaOSC);
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   FileClose(pso_handler);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   int i,j;
   for(i=0;i<=number_particles-1;i++)
     {
      int nop=getNroOperacionesGanadoras(set_particulas[i].magicNumber)+getNroOperacionesPerdedoras(set_particulas[i].magicNumber);
      int min_since_last_order=time_since_last_order_closed(set_particulas[i].magicNumber,2);
      
      int orders_opened=getOrdersOpened(set_particulas[i].magicNumber);
      
      if(reuneParaBuy(i) && set_particulas[i].cantOperaciones<max_operaciones)
        {
         if(min_since_last_order>global_minutes && orders_opened<=max_opened_orders)
           {
            
            comprar(i);
            Alert("Particula: "  +(string)i + " Min: " + (string)min_since_last_order + " Orders: " + (string)orders_opened + " NOP: " + (string)set_particulas[i].cantOperaciones);
            actualizarTPSL();
           }
         //max orders..
         //logica compra en base al i
        }

     }
     
      for(j=0;j<=number_particles-1;j++)
        {
         int nop= getNroOperacionesGanadoras(set_particulas[j].magicNumber)+getNroOperacionesPerdedoras(set_particulas[j].magicNumber);
         
         if(set_particulas[j].cantOperaciones>=max_operaciones)
           {
          
            double aptitud=fAptitud(set_particulas[j].magicNumber);
           
            double aptitudGlobal= globalbest.heuristica;
            double aptitudLocal = set_particulas[j].localBest.heuristica;
            bool isBest_than_global= aptitud < aptitudGlobal;
            bool isBest_than_local = aptitud < aptitudLocal;
            if(isBest_than_global){ update_global_to(set_particulas[j], j);  }
            if(isBest_than_local){ update_local_to(set_particulas[j], j);   }
            //Core de la actualización, si no es mejor que ninguno, actualizo
            
            actualizar_posicion(set_particulas[j]); 

           }
        }

     }

  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getOrdersOpened(int magic)
  {
   int total=OrdersTotal();
   int n=0;
   for(int i=total-1;i>=0;i--)
     {if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) && OrderMagicNumber()==magic){n++;}}

   return n;
  }
//+------------------------------------------------------------------+

void update_global_to(particle &part, int nroParticula)
  {
   globalbest.config.divRsi=part.confActual.divRsi;
   globalbest.config.divisorKeltber=part.confActual.divisorKeltber;
   globalbest.config.dmi=part.confActual.dmi;
   globalbest.config.zonaOSC=part.confActual.zonaOSC;
   globalbest.magicNumber=part.magicNumber;
   globalbest.heuristica = fAptitud(part.magicNumber);
   int gan= getNroOperacionesGanadoras(part.magicNumber);
   int per = getNroOperacionesPerdedoras(part.magicNumber);
   int tiempo = getTiempoPromedio(part.magicNumber);
   pso_handler = FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV,','); //open el file a memoria
   FileSeek(pso_handler,0,SEEK_END);
   //G FOR GLOBAL
   //L-nroParticula FOR LOCAL
   
   FileWrite(pso_handler,"G",globalbest.heuristica,gan,per,tiempo,globalbest.magicNumber ,globalbest.config.divRsi, globalbest.config.divisorKeltber, globalbest.config.zonaOSC);
   FileFlush(pso_handler);
   FileClose(pso_handler);
   //FileWrite(pso_handler,nroParticula,esGlobal?,heuristica,ganadas, perdidas, tiempo,Magic Number ,Rsi, Keltber, zonaOSC);
   
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void update_local_to(particle &part, int nroParticula)
  {
   part.localBest.config.divRsi=part.confActual.divRsi;
   part.localBest.config.divisorKeltber=part.confActual.divisorKeltber;
   part.localBest.config.dmi=part.confActual.dmi;
   part.localBest.config.zonaOSC=part.confActual.zonaOSC;
   part.localBest.heuristica = fAptitud(part.magicNumber);
   part.localBest.magicNumber=part.magicNumber;
   
   int gan= getNroOperacionesGanadoras(part.magicNumber);
   int per = getNroOperacionesPerdedoras(part.magicNumber);
   int tiempo = getTiempoPromedio(part.magicNumber);
   
   pso_handler = FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV,','); //open el file a memoria
   FileSeek(pso_handler,0,SEEK_END);
   FileWrite(pso_handler,"L-" + (string)nroParticula,part.localBest.heuristica,gan,per,tiempo,part.localBest.magicNumber ,part.localBest.config.divRsi, part.localBest.config.divisorKeltber, part.localBest.config.zonaOSC);
   FileFlush(pso_handler);
   FileClose(pso_handler);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actualizar_posicion(particle &particula)
  {

   double r1= NormalizeDouble(random_int(0,1),2);
   double r2= NormalizeDouble(random_int(0,1),2);
   double socialComponent=c2*r2;
   double inertia=w;
   double internalComponent=c1*r1;
  
   conf inertiaC,global_minus_x,local_minus_x;
   calculateInertia(inertiaC,particula.confActual);

   calculate_distance_from_global(global_minus_x,particula.confActual); //modulo de la distancia?
   calculate_distance_from_local(local_minus_x,particula.confActual,particula.localBest.config, particula.localBest.heuristica);
   
//x+1= x + wx + social + internal
//w[a,b,c,d,...,n]
//
   calculate_socandnostalgy(global_minus_x,socialComponent);
   calculate_socandnostalgy(local_minus_x,internalComponent);
   backup_valores(particula);
   act_pos_final(particula,inertiaC,global_minus_x,local_minus_x);
   
//x+1= wx + social + internal
//w[a,b,c,d,...,n]
//
   //validate_new_position(particula);
   
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool reuneParaBuy(int pos_in_array)
  {
   bool hayBuy=false;
   conf confParticula=getConfParticula(pos_in_array);
   bool buy1=buy_indicadorOne(confParticula.divRsi);
   bool buy2=buy_indicadorTwo(confParticula.divisorKeltber);
   bool buy3= buy_indicadorThree(confParticula.zonaOSC);
   bool buy4=true;
//agregar otros 2
   hayBuy=buy1 && buy2 && buy3;
   return hayBuy;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool buy_indicadorOne(double divrsi)
  {
   double rsi_value=iRSI(Symbol(),0,20,PRICE_CLOSE,1);
   double rsi_value1=iRSI(Symbol(),0,20,PRICE_CLOSE,2);
   bool a1=rsi_value>=rsi_value1;
   double shift_rsi=100*divrsi; // divrsi ~ (0,1)
   return ( a1 && rsi_value > shift_rsi);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool buy_indicadorTwo(double divKeltner)
  {
   double upper_kelt=iCustom(Symbol(),0,"Keltner",45,3,1,100,1.5,false,0,0);
   double mid_kelt = iCustom(Symbol(),0,"Keltner",45,3,1,100,1.5,false,1,0);
   double low_kelt = iCustom(Symbol(),0,"Keltner",45,3,1,100,1.5,false,2,0);
   double diff=(upper_kelt-low_kelt)*divKeltner;
   bool a = Close[0] > upper_kelt - diff;
   bool b = High[0] > Close[1];
   return (a && b);
  }
  
bool buy_indicadorThree(double oscvalue){
   double osc = iCustom(Symbol(),0,"LBR OSC",5,35,5,7,0);
   double osc1 = iCustom(Symbol(),0,"LBR OSC",5,35,5,7,1);
   bool a = osc > osc1;
   return (a && osc > oscvalue);

}  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
conf getConfParticula(int pos)
  {
   return (set_particulas[pos].confActual);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void calculate_distance_from_global(conf &fin,conf &act)
  {
   if(globalbest.heuristica == 99999){
      fin.divRsi = 0.0;
      fin.divisorKeltber = 0.0;
      fin.dmi = 0.0;
      fin.zonaOSC = 0.0; 
     } else {
      fin.divRsi=NormalizeDouble(globalbest.config.divRsi-act.divRsi,2);
      fin.divisorKeltber=NormalizeDouble(globalbest.config.divisorKeltber-act.divisorKeltber,2);
      fin.dmi=globalbest.config.dmi-act.dmi;
      fin.zonaOSC=NormalizeDouble(globalbest.config.zonaOSC-act.zonaOSC,6);}
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void calculate_distance_from_local(conf &fin,conf &act,conf &local, double h)
  {
  if(h == 99999){
      fin.divRsi = 0.0;
      fin.divisorKeltber = 0.0;
      fin.dmi = 0.0;
      fin.zonaOSC = 0.0; 
   fin.divRsi=NormalizeDouble(local.divRsi-act.divRsi,2);
   fin.divisorKeltber=NormalizeDouble(local.divisorKeltber-act.divisorKeltber,2);
   fin.dmi=local.dmi-act.dmi;
   fin.zonaOSC=NormalizeDouble(local.zonaOSC-act.zonaOSC,6);
  }}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void calculate_socandnostalgy(conf &act,double soc)
  {
   act.divRsi=NormalizeDouble(act.divRsi*soc,2);
   act.divisorKeltber=NormalizeDouble(act.divisorKeltber*soc,2);
   //act.dmi=act.dmi*soc;
   act.zonaOSC=NormalizeDouble(act.zonaOSC*soc,6);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void act_pos_final(particle &part,conf &inertia,conf &g_minus_x,conf &l_minus_x)
  {
 
   int nropart = getNroParticula(part.magicNumber);
   double aptitud = fAptitud(part.magicNumber);
   int gan= getNroOperacionesGanadoras(part.magicNumber);
   int per = getNroOperacionesPerdedoras(part.magicNumber);
   int tiempo = getTiempoPromedio(part.magicNumber);
   pso_handler = FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV,','); //open el file a memoria
   FileSeek(pso_handler,0,SEEK_END);
   FileWrite(pso_handler,(string)nropart,aptitud,gan,per,tiempo,part.magicNumber ,part.confActual.divRsi, part.confActual.divisorKeltber, part.confActual.zonaOSC);
   FileFlush(pso_handler);
   FileClose(pso_handler);
   part.confActual.divRsi=NormalizeDouble(part.confActual.divRsi+inertia.divRsi+g_minus_x.divRsi+l_minus_x.divRsi,2);
   part.confActual.divisorKeltber=NormalizeDouble(part.confActual.divisorKeltber+inertia.divisorKeltber+g_minus_x.divisorKeltber+l_minus_x.divisorKeltber,2);
   part.confActual.dmi=part.confActual.dmi+inertia.dmi+g_minus_x.dmi+l_minus_x.dmi;
   part.confActual.zonaOSC=NormalizeDouble(part.confActual.zonaOSC+inertia.zonaOSC+g_minus_x.zonaOSC+l_minus_x.zonaOSC,6);
   part.cantOperaciones = 0;
   int temp_magic=part.magicNumber+1;
   bool magic_updated=false;
   while(!magic_updated)
     {
     
     if(magic_is_free(temp_magic)){ part.magicNumber=temp_magic;  magic_updated =true;} else {temp_magic++;}
     }
   Print("Posicion actualizada: " + (string)part.confActual.divRsi );  


  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void backup_valores(particle &part)
  {
   part.confPrevia.divRsi=part.confActual.divRsi;
   part.confPrevia.divisorKeltber=part.confActual.divisorKeltber;
   part.confPrevia.zonaOSC=part.confActual.zonaOSC;
   part.confPrevia.dmi=part.confActual.dmi;
   part.magicNumber2=part.magicNumber;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void calculateInertia(conf &fconf,conf &particleConfiguration)
  {
   fconf.divRsi=particleConfiguration.divRsi*w;
   fconf.divisorKeltber=particleConfiguration.divisorKeltber*w;
   fconf.dmi=particleConfiguration.dmi*w;
   fconf.zonaOSC=particleConfiguration.zonaOSC*w;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double fAptitud(int magicNumber)
  {
   double aptitud=0.0;
   int nroGanadoras=getNroOperacionesGanadoras(magicNumber);
   int nroPerdedoras=getNroOperacionesPerdedoras(magicNumber);
   int tiempoPromedio=getTiempoPromedio(magicNumber);
//Cuanto mas chica es la f aptitud mejor
   double coef1,coef2,coef3;
   coef1 = coefGanadoras;
   coef2 = coefPerdedoras;
   coef3 = coefTiempo;
   //Penalizo por Perdidas > Ganadoras
   if(nroPerdedoras>=nroGanadoras){coef1=coefGanadoras; coef2=coefPerdedoras*5;}
   double apt_gan_vs_per=(coef1*nroGanadoras)+(coef2*nroPerdedoras);
   aptitud=apt_gan_vs_per+(coefTiempo*tiempoPromedio);   
//Penalizo por tiempo
   if(minutosMinimo<tiempoPromedio){ aptitud+=coefTiempo*tiempoPromedio*10; }
   return NormalizeDouble(aptitud,4);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getTiempoPromedio(int mn)
  {

   int total=OrdersHistoryTotal()-1;
   int tiempototal=0;
   int n=0;
   int promedio=0;

   for(int i=total-1;i>=0;i--)
     {

      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY) && OrderMagicNumber()==mn)
        {
         tiempototal=tiempototal+TimeHour(OrderCloseTime()-OrderOpenTime())*60+TimeMinute(OrderCloseTime()-OrderOpenTime());
         n++;
        }
     }
     if(n==0){promedio = 99999;} else {promedio=tiempototal/n;}
   
   return promedio;
  }
//+------------------------------------------------------------------+
int getNroOperacionesGanadoras(int magic)
  {
   int total=OrdersHistoryTotal()-1;
   int n=0;

   for(int i=total;i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY) && OrderMagicNumber()==magic && OrderProfit()>0){n++;}
     }
   return n;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getNroOperacionesPerdedoras(int magic)
  {
   int total=OrdersHistoryTotal()-1;
   int tiempototal=0;
   int n=0;
   int promedio=0;

   for(int i=total;i>=0;i--)
     {

      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY) && OrderMagicNumber()==magic && OrderProfit()<=0.0){n++;}
     }
   return n;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double random_int(double end,double beg=0.0)
  { // Return a random number in the range [b, e).
   return double( beg + (end - beg) * MathRand() / 32768.);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int time_since_last_order_closed(int magic,int tipo)
  {
   datetime time_now=Time[0];
   datetime lastclosed= LastOrderTicket_closed(magic);
   datetime lastopened= LastOrderTicket_opened(magic);
   int minutes_from_closed = TimeHour(Time[0]-lastclosed)*60 + TimeMinute(Time[0]-lastclosed);
   int minutes_from_opened = TimeHour(Time[0]-lastopened)*60 + TimeMinute(Time[0]-lastopened);
   int ret = 0;
   if(tipo == 1){ret = minutes_from_opened; } //open orders
   if(tipo == 2){ret = minutes_from_closed; } //history orders
   return ret;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool order_can_be_opened_vs_time(int magic,int tipo)
  {
   bool a=true;
   int minutes=time_since_last_order_closed(magic,tipo);
   return (minutes >= global_minutes);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime LastOrderTicket_opened(int magic)
  {
   datetime lastOrderTime=0;
   int  lastOrderTicket=-4;
   for(int j=0; j<OrdersTotal(); j++)
     {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==True && OrderMagicNumber()==magic && OrderSymbol()==Symbol())
        {
         if(OrderType()<2)
           {
            if(OrderOpenTime()>lastOrderTime)
              {
               lastOrderTime=OrderOpenTime();
              }
            else     continue;
           }
         else   continue;
        }
      else      continue;
     }
   return(lastOrderTime);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime LastOrderTicket_closed(int magic)
  {
   datetime lastOrderTime=0;
   int  lastOrderTicket=-4;
   for(int j=0; j<OrdersHistoryTotal()-1; j++)
     {
      if(OrderSelect(j,SELECT_BY_POS,MODE_HISTORY)==True && OrderMagicNumber()==magic && OrderSymbol()==Symbol())
        {
         if(OrderType()<2)
           {
            if(OrderCloseTime()>lastOrderTime)
              {
               lastOrderTime=OrderCloseTime();
              }
            else     continue;
           }
         else   continue;
        }
      else      continue;
     }
   return(lastOrderTime);
  }
//+------------------------------------------------------------------+

void comprar(int pos_particle)
  {
   double Lot=0.1;
   double OpenPrice=Ask;
   int Slippage=10;
   int mg=set_particulas[pos_particle].magicNumber;
   int Buy;
   int particula=pos_particle+1;
   Buy=OrderSend(Symbol(),OP_BUY,Lot,OpenPrice,Slippage,0,0,"PSO: "+string(particula),mg,0,clrSalmon);//0,0 reemplazar por Loss,Tprofit
   if(Buy<0)
     {Print("BUY: OrderSend failed with error #",GetLastError());} else {set_particulas[pos_particle].cantOperaciones++;}

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool magic_is_free(int magic)
  {

   bool free=false;
   bool used_by_particle=number_used_by_particle(magic);
   bool in_use=number_is_in_use(magic);
   return (!used_by_particle && !in_use);


  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool number_is_in_use(int magic)
  {
   bool inuse=false;
   for(int i=0;i<=number_particles-1;i++)
     {
      if(set_particulas[i].magicNumber==magic)
        {
         inuse=true;
         break;
        }
     }
   return inuse;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool number_used_by_particle(int magic)
  {
   bool in=false;
   int nro = getNroOperacionesGanadoras(magic) + getNroOperacionesPerdedoras(magic);
   if(nro!=0){in=true;}
   return in;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void validate_new_position(particle &particula)
  {

   if(!(particula.confActual.divRsi>0.10 && particula.confActual.divRsi<0.90)){ particula.confActual.divRsi=NormalizeDouble(random_int(0.1,0.9),2); }
  if(!(particula.confActual.divisorKeltber>0.10 && particula.confActual.divisorKeltber<0.90)){ particula.confActual.divisorKeltber=NormalizeDouble(random_int(0.1,0.9),2); }
   if(!(particula.confActual.zonaOSC>-0.009999 && particula.confActual.zonaOSC<0.009999))
     {
      double ic=NormalizeDouble((-1.0)*0.005000,6);
      particula.confActual.zonaOSC=NormalizeDouble(random_int(ic,0.006000),6);
     }
   int nropart = getNroParticula(particula.magicNumber);
   double aptitud = fAptitud(particula.magicNumber2);
   int gan= getNroOperacionesGanadoras(particula.magicNumber2);
   int per = getNroOperacionesPerdedoras(particula.magicNumber2);
   int tiempo = getTiempoPromedio(particula.magicNumber2);
   pso_handler = FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV,','); //open el file a memoria
   FileSeek(pso_handler,0,SEEK_END);
   FileWrite(pso_handler,(string)nropart,aptitud,gan,per,tiempo,particula.magicNumber ,particula.confActual.divRsi, particula.confActual.divisorKeltber, particula.confActual.zonaOSC);
   FileClose(pso_handler);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void initialize_particle(particle &particula, int mg)
  {
   particula.confActual.divRsi=NormalizeDouble(random_int(0.1,0.9),2);
   particula.confActual.divisorKeltber=NormalizeDouble(random_int(0.1,0.9),2);
   double ic=NormalizeDouble((-1.0)*0.009000,6);
   particula.confActual.zonaOSC=NormalizeDouble(random_int(ic,0.005000),6);
   particula.localBest.heuristica = 99999;
   particula.magicNumber = mg;
   particula.cantOperaciones = 0;
   Print("Particula Inicializada: " + (string)(mg-10) + "RSI: " + (string)particula.confActual.divRsi + " K:" + (string)particula.confActual.divisorKeltber + " Aptitud: " + (string)particula.localBest.heuristica + " OSC:" + (string)particula.confActual.zonaOSC);
   
  }
/////////////////////////

void actualizarTPSL()
  {

   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {

         if(OrderType()==OP_BUY)
           {
            if(OrderStopLoss()==0 || OrderTakeProfit()==0)
              {
               double SL=NormalizeDouble(MarketInfo(OrderSymbol(),MODE_BID)-pips_sl*MarketInfo(OrderSymbol(),MODE_POINT),Digits);
               double TP=NormalizeDouble(MarketInfo(OrderSymbol(),MODE_BID)+pips_tp*MarketInfo(OrderSymbol(),MODE_POINT),Digits);
               if(!OrderModify(OrderTicket(),OrderOpenPrice(),SL,TP,0,clrNONE))Print("error: ",GetLastError());
              }
           }
        }


     }

  }
//+------------------------------------------------------------------
void initialize_global(){
globalbest.heuristica = 99999;
}

int getNroParticula(int magic){
int a=9999;
for(int i=0;i<=number_particles-1;i++)
  {
   if(set_particulas[i].magicNumber == magic){a = i; break; }
  }
return a;
}