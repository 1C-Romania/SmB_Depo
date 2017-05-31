Function AllowAccountsExtDimensionsInManagedForm(Val AccountName, Val ExtDimensionName, Object, FormItems) Export
	
	Account = Object[AccountName];
	AccountExtDimensionsCount = CommonAtServerCached.GetBookkeepingAccountExtDimensionsCount(Account);
	MaxAccountExtDimensionsCount = CommonAtServerCached.GetBookkeepingMaxExtDimensionsCount();
	
	For Counter = 1 To MaxAccountExtDimensionsCount Do	
		//FormItems[ExtDimensionName+Counter].ReadOnly = ( Not ValueIsFilled(Account) Or Counter > AccountExtDimensionsCount);				
		If Not ValueIsFilled(Account) Or Counter > AccountExtDimensionsCount Then
			FormItems[ExtDimensionName+Counter].ReadOnly = True;							
			FormItems[ExtDimensionName+Counter].InputHint = "";					
		Else	
			FormItems[ExtDimensionName+Counter].ReadOnly = False;										
			FormItems[ExtDimensionName+Counter].InputHint = CommonAtServer.GetAttribute(CommonAtServer.GetAttribute(Account,"ExtDimension" + String(Counter) + "Type"),"Description");							
		EndIf;
	EndDo;
	
EndFunction	

