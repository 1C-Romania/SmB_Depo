Function GetCurrentUserLanguageCode() Export 	
	
	Language = InfoBaseUsers.CurrentUser().Language;
	
	If Language <> Undefined  Then
		Return Language.LanguageCode;
	EndIf;
	
	Return "";	
        
Endfunction

Function GetObjectPresentation(Ref,LanguageCode,CatalogDescription) Export	
	 
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	PresentationsTable.Presentation
		|FROM
		|	Catalog."+CatalogDescription+".MultilingualPresentations AS PresentationsTable
		|WHERE
		|	PresentationsTable.Ref = &Ref
		|	AND PresentationsTable.LanguageCode = &LanguageCode";
	
	Query.SetParameter("LanguageCode", LanguageCode);
	Query.SetParameter("Ref"		 , Ref);
	
	QueryResult = Query.Execute();
	
	If  Not QueryResult.IsEmpty() Then
		
		SelectionDetailRecords = QueryResult.Select();
		
		SelectionDetailRecords.Next();
		
		Return SelectionDetailRecords.Presentation;
		
	EndIf;  
	
	Return Undefined;	
	
	
Endfunction	