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
struct best  
  {
   conf              config;
   int               magicNumber;
   double            heuristica;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct particle
  {
   int               magicNumber;
   int               magicNumber2;
   conf              confActual;
   conf              confPrevia;
   best              localBest;
   int               magicNumber_localBest;
   datetime          fechaActualizacion;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


extern int    number_particles=50;
extern double c2= 0.99; //Social Component
extern double c1 = 0.0; //Nostalgy Component
extern double w=0.0; //Inertia
extern int max_operaciones=10; //Cantidad op. x ciclo
extern string asd="-------------------------------------"; // ---------------
 double coefGanadoras=1.0; //Coeficiente Ganadoras ~ (0,1)
 double coefPerdedoras=1.0; //Coeficiente Perdedor ~ (0,1)
 double coefTiempo=1.0; //Coeficiente Tiempo ~ (0,1)
extern int    minutosMinimo=20; //Minutos promedio a tender
extern double max_tiempo_limite=200; //Maximo tiempo en horas sin operar
extern int pips_tp = 100; // Ticks - Takeprofit
extern int pips_sl = 200; // Ticks - Stop Loss
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
   filename=(string)Symbol()+"_"+(string)Period()+"_"+filename;
   ArrayResize(set_particulas,1000);
   globalbest.magicNumber=1234;
   for(int i=0;i<=number_particles-1;i++)
     {
      initialize_particle(set_particulas[i],10+i);
     }
   initialize_global();
   if(FileIsExist(filename)){FileDelete(filename);}
   pso_handler=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV,','); //open el file a memoria
   if(pso_handler<0)
     {
      Print("Failed to open the file by the absolute path");
      Print("Error code ",GetLastError());
     }
   FileWrite(pso_handler,"Particula" , "Fecha Actualizacion","Heuristica/Aptitud","Op. Ganadas","Op. Perdidas","Tiempo","Magic Number","Config RSI","Config Keltner","Config OSC");
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
TakeProfitOrStopLoss();
//if(time0<Time[0] && TimeCurrent() >= Time[0]+900)
if(time0<Time[0] && TimeCurrent() > Time[0]+((PERIOD_CURRENT*60)/2))
  {
   time0 = Time[0];
   
      int i,j;
   for(i=0;i<=number_particles-1;i++)
     {
      int nop=getNroOperacionesGanadoras(set_particulas[i].magicNumber)+getNroOperacionesPerdedoras(set_particulas[i].magicNumber);
      int min_since_last_closed_order=time_since_last_order_closed(set_particulas[i].magicNumber,2);
      int min_since_last_opened_order=time_since_last_order_closed(set_particulas[i].magicNumber,1);
      int orders_opened=getOrdersOpened(set_particulas[i].magicNumber);

      if(reuneParaBuy(i) && nop<max_operaciones)
        {
         if(min_since_last_closed_order>global_minutes && min_since_last_opened_order>global_minutes && orders_opened<=max_opened_orders)
           {

            comprar(i);
            //actualizarTPSL();
           }

        }
      check_update_after_time(i);
     }

   for(j=0;j<=number_particles-1;j++)
     {
      int nop=getNroOperacionesGanadoras(set_particulas[j].magicNumber)+getNroOperacionesPerdedoras(set_particulas[j].magicNumber);

      if(nop>=max_operaciones)
        { init_update_process(j,1); }

     }
  }

   
  }
  
void init_update_process(int j, int type_upd){
   int nop=getNroOperacionesGanadoras(set_particulas[j].magicNumber)+getNroOperacionesPerdedoras(set_particulas[j].magicNumber);
   double aptitud=8888;
   if(nop>=max_operaciones){aptitud=fAptitud(set_particulas[j].magicNumber); } else {aptitud = 8888;}
   double aptitudGlobal= globalbest.heuristica;
   double aptitudLocal = set_particulas[j].localBest.heuristica;
   bool isBest_than_global= aptitud < aptitudGlobal;
   bool isBest_than_local = aptitud < aptitudLocal;

   //Core de la actualización, si no es mejor que ninguno, actualizo
   
   switch(type_upd)
   {
   case 1: //Normal update
      if(isBest_than_global){ update_global_to(set_particulas[j],j);  }
      if(isBest_than_local){ update_local_to(set_particulas[j],j);   }
      actualizar_posicion(set_particulas[j],1);
     break;
     
    case 2:  //max time
    actualizar_posicion(set_particulas[j],2);
    break;
      default:
       break;
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

void update_global_to(particle &part,int nroParticula)
  {
   globalbest.config.divRsi=part.confActual.divRsi;
   globalbest.config.divisorKeltber=part.confActual.divisorKeltber;
   globalbest.config.dmi=part.confActual.dmi;
   globalbest.config.zonaOSC=part.confActual.zonaOSC;
   globalbest.magicNumber=part.magicNumber;
   globalbest.heuristica = fAptitud(part.magicNumber);
   int gan= getNroOperacionesGanadoras(part.magicNumber);
   int per= getNroOperacionesPerdedoras(part.magicNumber);
   int tiempo=getTiempoPromedio(part.magicNumber);
   pso_handler=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV,','); //open el file a memoria
   FileSeek(pso_handler,0,SEEK_END);
//G FOR GLOBAL
//L-nroParticula FOR LOCAL
   string dateupdate = (string)Year() + "/" + (string)Month() + "/" + (string)Day() + " " + (string)Hour() + ":" + (string)Minute();
   FileWrite(pso_handler,"G",dateupdate,globalbest.heuristica,gan,per,tiempo,globalbest.magicNumber,globalbest.config.divRsi,globalbest.config.divisorKeltber,globalbest.config.zonaOSC);
   FileFlush(pso_handler);
   FileClose(pso_handler);
//FileWrite(pso_handler,nroParticula,esGlobal?,heuristica,ganadas, perdidas, tiempo,Magic Number ,Rsi, Keltber, zonaOSC);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void update_local_to(particle &part,int nroParticula)
  {
   part.localBest.config.divRsi=part.confActual.divRsi;
   part.localBest.config.divisorKeltber=part.confActual.divisorKeltber;
   part.localBest.config.dmi=part.confActual.dmi;
   part.localBest.config.zonaOSC=part.confActual.zonaOSC;
   part.localBest.heuristica = fAptitud(part.magicNumber);
   part.localBest.magicNumber=part.magicNumber;

   int gan= getNroOperacionesGanadoras(part.magicNumber);
   int per= getNroOperacionesPerdedoras(part.magicNumber);
   int tiempo=getTiempoPromedio(part.magicNumber);
   string dateupdate = (string)Year() + "/" + (string)Month() + "/" + (string)Day() + " " + (string)Hour() + ":" + (string)Minute();
   pso_handler=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV,','); //open el file a memoria
   FileSeek(pso_handler,0,SEEK_END);
   FileWrite(pso_handler,"L-"+(string)nroParticula,dateupdate,part.localBest.heuristica,gan,per,tiempo,part.localBest.magicNumber,part.localBest.config.divRsi,part.localBest.config.divisorKeltber,part.localBest.config.zonaOSC);
   FileFlush(pso_handler);
   FileClose(pso_handler);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void actualizar_posicion(particle &particula, int type_update)
  {

   double r1= NormalizeDouble(random_int(0,1),2);
   double r2= NormalizeDouble(random_int(0,1),2);
   double socialComponent=c2*r2;
   double inertia=w;
   double internalComponent=c1*r1;

   conf inertiaC,global_minus_x,local_minus_x;
   calculateInertia(inertiaC,particula.confActual);

   calculate_distance_from_global(global_minus_x,particula.confActual); //modulo de la distancia?
   calculate_distance_from_local(local_minus_x,particula.confActual,particula.localBest.config,particula.localBest.heuristica);

//x+1= x + wx + social + internal
//w[a,b,c,d,...,n]
//
   calculate_socandnostalgy(global_minus_x,socialComponent);
   calculate_socandnostalgy(local_minus_x,internalComponent);
   backup_valores(particula);
   switch(type_update)
     {
      case  1: //NOrmal update
        act_pos_final(particula,inertiaC,global_minus_x,local_minus_x);
        
        break;
        
      case 2: //Update by max inactive time reached
      act_pos_final_forced(particula,inertiaC,global_minus_x,local_minus_x);
      default:
        break;
     }
   
//x+1= wx + social + internal
//w[a,b,c,d,...,n]
//
      validate_new_position(particula);
   

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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool buy_indicadorThree(double oscvalue)
  {
   double osc=iCustom(Symbol(),0,"LBR OSC",5,35,5,7,0);
   double osc1=iCustom(Symbol(),0,"LBR OSC",5,35,5,7,1);
   bool a=osc>=osc1;
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
   if(globalbest.heuristica==99999)
     {
      fin.divRsi=0.0;
      fin.divisorKeltber=0.0;
      fin.dmi=0.0;
      fin.zonaOSC=0.0;
        } else {
      fin.divRsi=NormalizeDouble(globalbest.config.divRsi-act.divRsi,2);
      fin.divisorKeltber=NormalizeDouble(globalbest.config.divisorKeltber-act.divisorKeltber,2);
      fin.dmi=globalbest.config.dmi-act.dmi;
      fin.zonaOSC=NormalizeDouble(globalbest.config.zonaOSC-act.zonaOSC,6);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void calculate_distance_from_local(conf &fin,conf &act,conf &local,double h)
  {
   if(h==99999)
     {
      fin.divRsi=0.0;
      fin.divisorKeltber=0.0;
      fin.dmi=0.0;
      fin.zonaOSC=0.0; }
         else {
      fin.divRsi=NormalizeDouble(local.divRsi-act.divRsi,2);
      fin.divisorKeltber=NormalizeDouble(local.divisorKeltber-act.divisorKeltber,2);
      fin.dmi=local.dmi-act.dmi;
      fin.zonaOSC=NormalizeDouble(local.zonaOSC-act.zonaOSC,6);}
      
     
  }
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

   int nropart=getNroParticula(part.magicNumber);
   double aptitud=fAptitud(part.magicNumber);
   int gan= getNroOperacionesGanadoras(part.magicNumber);
   int per= getNroOperacionesPerdedoras(part.magicNumber);
   int tiempo=getTiempoPromedio(part.magicNumber);
   pso_handler=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV,','); //open el file a memoria
   FileSeek(pso_handler,0,SEEK_END);
   string dateupdate = (string)TimeYear(part.fechaActualizacion) + "/" + (string)TimeMonth(part.fechaActualizacion) + "/" + (string)TimeDay(part.fechaActualizacion) + " " + (string)TimeHour(part.fechaActualizacion) + ":" + (string)TimeMinute(part.fechaActualizacion);
   FileWrite(pso_handler,(string)nropart,dateupdate,aptitud,gan,per,tiempo,part.magicNumber,part.confActual.divRsi,part.confActual.divisorKeltber,part.confActual.zonaOSC);
   FileFlush(pso_handler);
   FileClose(pso_handler);
   part.confActual.divRsi=NormalizeDouble(part.confActual.divRsi+inertia.divRsi+g_minus_x.divRsi+l_minus_x.divRsi,2);
   part.confActual.divisorKeltber=NormalizeDouble(part.confActual.divisorKeltber+inertia.divisorKeltber+g_minus_x.divisorKeltber+l_minus_x.divisorKeltber,2);
   part.confActual.dmi=part.confActual.dmi+inertia.dmi+g_minus_x.dmi+l_minus_x.dmi;
   part.confActual.zonaOSC=NormalizeDouble(part.confActual.zonaOSC+inertia.zonaOSC+g_minus_x.zonaOSC+l_minus_x.zonaOSC,6);

   part.fechaActualizacion=Time[0];
   int temp_magic=part.magicNumber+1;
   bool magic_updated=false;
   while(!magic_updated)
     {

      if(magic_is_free(temp_magic)){ part.magicNumber=temp_magic;  magic_updated=true;} else {temp_magic++;}
     }
   Print("Posicion actualizada: "+(string)part.confActual.divRsi);

  }
  
void act_pos_final_forced(particle &part,conf &inertia,conf &g_minus_x,conf &l_minus_x)
  {

   int nropart=getNroParticula(part.magicNumber);
   double aptitud=15000;
   int gan= getNroOperacionesGanadoras(part.magicNumber);
   int per= getNroOperacionesPerdedoras(part.magicNumber);
   int tiempo=getTiempoPromedio(part.magicNumber);
   pso_handler=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV,','); //open el file a memoria
   FileSeek(pso_handler,0,SEEK_END);
   string dateupdate = (string)TimeYear(part.fechaActualizacion) + "/" + (string)TimeMonth(part.fechaActualizacion) + "/" + (string)TimeDay(part.fechaActualizacion) + " " + (string)TimeHour(part.fechaActualizacion) + ":" + (string)TimeMinute(part.fechaActualizacion);
   FileWrite(pso_handler,(string)nropart,dateupdate,aptitud,gan,per,tiempo,part.magicNumber,part.confActual.divRsi,part.confActual.divisorKeltber,part.confActual.zonaOSC);
   FileFlush(pso_handler);
   FileClose(pso_handler);
   part.confActual.divRsi=NormalizeDouble(part.confActual.divRsi+inertia.divRsi+g_minus_x.divRsi+l_minus_x.divRsi,2);
   part.confActual.divisorKeltber=NormalizeDouble(part.confActual.divisorKeltber+inertia.divisorKeltber+g_minus_x.divisorKeltber+l_minus_x.divisorKeltber,2);
   part.confActual.dmi=part.confActual.dmi+inertia.dmi+g_minus_x.dmi+l_minus_x.dmi;
   part.confActual.zonaOSC=NormalizeDouble(part.confActual.zonaOSC+inertia.zonaOSC+g_minus_x.zonaOSC+l_minus_x.zonaOSC,6);

   part.fechaActualizacion=Time[0];
   int temp_magic=part.magicNumber+1;
   bool magic_updated=false;
   while(!magic_updated)
     {

      if(magic_is_free(temp_magic)){ part.magicNumber=temp_magic;  magic_updated=true;} else {temp_magic++;}
     }
   Print("Posicion actualizada por Fuerza: "+(string)part.confActual.divRsi);

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
   double proporcion_op=NormalizeDouble(nroPerdedoras*100/max_operaciones,2);
   double proporcion_tiempo=NormalizeDouble(tiempoPromedio/minutosMinimo,2);
//Cuanto mas chica es la f aptitud mejor
   double coef1,coef2,coef3;
   coef1 = coefGanadoras;
   coef2 = coefPerdedoras*proporcion_op;
   coef3 = coefTiempo;
//Penalizo por Perdidas > Ganadoras
   double apt_gan_vs_per=(coef1*nroGanadoras)+(coef2*nroPerdedoras);
   aptitud=apt_gan_vs_per+(coefTiempo*tiempoPromedio);
//Penalizo por tiempo
   aptitud+=coefTiempo*proporcion_tiempo;
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
   if(n==0){promedio=99999;} else {promedio=tiempototal/n;}

   return promedio;
  }
//+------------------------------------------------------------------+
int getNroOperacionesGanadoras(int magic)
  {
   int total=OrdersHistoryTotal()-1;
   int n=0;

   for(int i=total;i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY) && OrderMagicNumber()==magic && OrderProfit()>0.0){n++;}
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
     {Print("BUY: OrderSend failed with error #",GetLastError());}

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
   int nro= getNroOperacionesGanadoras(magic)+getNroOperacionesPerdedoras(magic);
   if(nro!=0){in=true;}
   return in;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void validate_new_position(particle &particula)
  {
   bool cambio = false;
   if(particula.confActual.divRsi<0.10){ particula.confActual.divRsi= particula.confActual.divRsi + NormalizeDouble(random_int(0.1,0.3),2); cambio = true;}
   if(particula.confActual.divRsi>0.90){ particula.confActual.divRsi= particula.confActual.divRsi - NormalizeDouble(random_int(0.1,0.3),2); cambio = true;}
   if(particula.confActual.divisorKeltber<0.10){  particula.confActual.divisorKeltber= particula.confActual.divisorKeltber + NormalizeDouble(random_int(0.1,0.3),2); cambio = true; }
   if(particula.confActual.divisorKeltber>0.90){  particula.confActual.divisorKeltber=particula.confActual.divisorKeltber - NormalizeDouble(random_int(0.1,0.3),2); cambio = true; }
   if(!(particula.confActual.zonaOSC>-0.009999 && particula.confActual.zonaOSC<0.009999))
     {
     // double ic=NormalizeDouble((-1.0)*0.005000,6);
     // particula.confActual.zonaOSC=NormalizeDouble(random_int(ic,0.006000),6);
     }
   if(cambio)
     {
      int nropart=getNroParticula(particula.magicNumber);
      double aptitud=fAptitud(particula.magicNumber2);
      int gan= getNroOperacionesGanadoras(particula.magicNumber2);
      int per= getNroOperacionesPerdedoras(particula.magicNumber2);
      int tiempo=getTiempoPromedio(particula.magicNumber2);
      pso_handler=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV,','); //open el file a memoria
      string dateupdate = (string)TimeYear(particula.fechaActualizacion) + "/" + (string)TimeMonth(particula.fechaActualizacion) + "/" + (string)TimeDay(particula.fechaActualizacion)  + " " + (string)TimeHour(particula.fechaActualizacion) + ":" + (string)TimeMinute(particula.fechaActualizacion);
      FileSeek(pso_handler,0,SEEK_END);
      FileWrite(pso_handler,(string)nropart,dateupdate,aptitud,gan,per,tiempo,particula.magicNumber2,particula.confPrevia.divRsi,particula.confPrevia.divisorKeltber,particula.confPrevia.zonaOSC);
      FileClose(pso_handler);
     }
   

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void initialize_particle(particle &particula,int mg)
  {
   particula.confActual.divRsi=NormalizeDouble(random_int(0.1,0.9),2);
   particula.confActual.divisorKeltber=NormalizeDouble(random_int(0.1,0.9),2);
   double ic=NormalizeDouble((-1.0)*0.009000,6);
   particula.confActual.zonaOSC=NormalizeDouble(random_int(ic,0.005000),6);
   particula.localBest.heuristica=99999;
   particula.magicNumber=mg;
   particula.fechaActualizacion=Time[0];
   Print("Particula Inicializada: "+(string)(mg-10)+"RSI: "+(string)particula.confActual.divRsi+" K:"+(string)particula.confActual.divisorKeltber+" OSC:"+(string)particula.confActual.zonaOSC);

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
               double SL=NormalizeDouble(MarketInfo(OrderSymbol(),MODE_BID)-(pips_sl*MarketInfo(OrderSymbol(),MODE_POINT)),Digits);
               double TP=NormalizeDouble(MarketInfo(OrderSymbol(),MODE_BID)+(pips_tp*MarketInfo(OrderSymbol(),MODE_POINT)),Digits);
               if(!OrderModify(OrderTicket(),OrderOpenPrice(),SL,TP,0,clrNONE))Print("error: ",GetLastError());
              }
           }
        }

     }

  }
//+------------------------------------------------------------------
void initialize_global()
  {
   globalbest.heuristica=99999;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getNroParticula(int magic)
  {
   int a=9999;
   for(int i=0;i<=number_particles-1;i++)
     {
      if(set_particulas[i].magicNumber==magic){a=i; break; }
     }
   return a;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void check_update_after_time(int nroParticula)
  {

   datetime f_ultimo_update=set_particulas[nroParticula].fechaActualizacion;
   datetime hoy = Time[0];
   double resto =TimeDay(hoy-f_ultimo_update)*24 +TimeHour(hoy-f_ultimo_update) + (TimeMinute(hoy-f_ultimo_update)/60);
   int op = getNroOperacionesGanadoras(set_particulas[nroParticula].magicNumber) + getNroOperacionesPerdedoras((set_particulas[nroParticula].magicNumber));
   if(resto>=max_tiempo_limite && op < ((int)max_operaciones/2)){
   Print("Tiempo maximo alcanzado por la particula: " + (string)nroParticula + ". Actualizando");
   init_update_process(nroParticula, 2);}
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TakeProfitOrStopLoss() 
  {

   int num=(int) pips_tp;
   int Slippage=10;
   double profittarget=num*Point;
   double sl = pips_sl*Point();

   for(int cnt=0; cnt<=OrdersTotal(); cnt++) 
     {
      bool OS=OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
      if(OS==true && OrderSymbol()==Symbol() && (OrderType()==OP_BUY)) 
        {
        if(Bid>=(OrderOpenPrice()+profittarget))
        {  bool ordCls=OrderClose(OrderTicket(),OrderLots(),Bid,Slippage,Blue); } 
        if(Bid<=(OrderOpenPrice()-sl))
        {  bool ordCls=OrderClose(OrderTicket(),OrderLots(),Bid,Slippage,Red); }         
        }

      if(OS==true && OrderSymbol()==Symbol() && (OrderType()==OP_SELL)) 
        {
         if(Ask<=(OrderOpenPrice()-profittarget)) 
           { bool ordCls=OrderClose(OrderTicket(),OrderLots(),Ask,Slippage,Blue);  }
         if(Ask<=(OrderOpenPrice()+sl)) 
           { bool ordCls=OrderClose(OrderTicket(),OrderLots(),Ask,Slippage,Red);  }  
        }
     }
  }
//+------------------------------------------------------------------+
