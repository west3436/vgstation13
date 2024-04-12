//Base ideal fermenting conditions
#define FERMENT_TEMP_LOWER (T0C + 20)
#define FERMENT_TEMP_UPPER (T0C + 30)

//Fermenting limits
#define OG_LIMIT 1.150
#define FG_LIMIT 0.990

//Specific gravities
#define BASE_SG_FRUIT 1.050
#define BASE_SG_HONEY 1.425

//Yeast health
#define YEAST_TEMP_LOWER (T0C + 5)
#define YEAST_TEMP_UPPER (T0C + 35)
#define YEAST_CONSUMPTION_RATE 0.01 //base sugar consumption rate per 10 second tick (max to min SG in ~27min)

//Helpers
#define SG_TO_ABV 131.25
