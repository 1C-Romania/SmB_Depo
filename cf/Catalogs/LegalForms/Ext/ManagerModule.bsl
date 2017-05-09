#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region ServiceProceduresAndFunctions

Procedure FillAvailableLegalForms() Export

	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	LegalForms.Ref AS LegalForm
		|FROM
		|	Catalog.LegalForms AS LegalForms";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	// 1. LLC
	LegalForm = Catalogs.LegalForms.CreateItem();
	LegalForm.Description	= "Limited Liability Company";
	LegalForm.ShortName		= "LLC";
	
	InfobaseUpdate.WriteData(LegalForm);
	
	// 2. FZE
	LegalForm = Catalogs.LegalForms.CreateItem();
	LegalForm.Description	= "Free Zone Establishment";
	LegalForm.ShortName		= "FZE";
	
	InfobaseUpdate.WriteData(LegalForm);
	
	// 3. FZCO
	LegalForm = Catalogs.LegalForms.CreateItem();
	LegalForm.Description	= "Free Zone Company";
	LegalForm.ShortName		= "FZCO";
	
	InfobaseUpdate.WriteData(LegalForm);

EndProcedure

#EndRegion

#EndIf