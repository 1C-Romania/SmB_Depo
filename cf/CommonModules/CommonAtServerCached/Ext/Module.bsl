Function GetBookkeepingAccountExtDimensionsCount(Val Account) Export
	
	Return ChartsOfAccounts.Bookkeeping.GetAccountExtDimensionsCount(Account);
	
EndFunction	

Function GetBookkeepingMaxExtDimensionsCount() Export
	
	Return ChartsOfAccounts.Bookkeeping.GetMaxExtDimensionsCount();	
	
EndFunction	

Function DefaultCompany() Export 
	Query	= New Query("SELECT TOP 1
	     	            |	Companies.Ref
	     	            |FROM
	     	            |	Catalog.Companies AS Companies
	     	            |
	     	            |ORDER BY
						|	Companies.DeletionMark ASC,
	     	            |	Companies.Code ASC");
	Result	= Query.Execute();
	
	If Result.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Selection	= Result.Select();
	
	Selection.Next();
	
	Return Selection.Ref;
EndFunction