#define QDEL_NULL(item) qdel(item); item = null
#define QDEL_LIST(L) if(L) { for(var/I in L) { qdel(I); } }
#define QDEL_LIST_ASSOC(L) if(L) { for(var/I in L) { qdel(L[I]); qdel(I); } }

#define QDEL_LIST_NULL(L) QDEL_LIST(L); L = null
#define QDEL_LIST_ASSOC_NULL(L) QDEL_LIST_ASSOC(L); L = null
#define QDEL_LIST_CUT(L) QDEL_LIST(L); L.Cut()
#define QDEL_LIST_ASSOC_CUT(L) QDEL_LIST_ASSOC(L); L.Cut()

#define QDELING(X) (X.gcDestroyed)
#define QDELETED(X) (!X || QDELING(X))
#define QDESTROYING(X) (!X || X.gcDestroyed == GC_CURRENTLY_BEING_QDELETED)
