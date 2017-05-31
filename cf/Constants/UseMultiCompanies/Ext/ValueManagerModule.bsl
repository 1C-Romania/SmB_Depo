
Procedure BeforeWrite(Cancel)
	If Value Then
		
		Return;
	
	EndIf;
	
	Query	= New Query("SELECT
	     	            |	Companies.Ref
	     	            |FROM
	     	            |	Catalog.Companies AS Companies");
	Result	= Query.Execute();
	
	If Not Result.IsEmpty() Then 
		Selection	= Result.Select();
		
		If Selection.Count() > 1 Then
			
			Cancel = True;
			
		EndIf;		
	EndIf;
EndProcedure
