Function GetMaxExtDimensionsCount() Export
	
	Return Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount;
	
EndFunction	

Function GetAccountExtDimensionsCount(Val Account) Export
	
	Return Account.ExtDimensionTypes.Count();
	
EndFunction	