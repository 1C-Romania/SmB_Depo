
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	//Paste handler content.
	//FormParameters = New Structure("", );
	//OpenForm("CommonForm.", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
	
	If CommonAtServer.UseMultiCompaniesMode() Then
		
		OpenForm("Catalog.Companies.ListForm", , CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness);
		
	Else 
		
		DefaultCompany	= CommonAtServerCached.DefaultCompany();
		
		If NOT ValueIsFilled(DefaultCompany) Then
			
			DefaultCompany	= CreateDefaultCompany();
			
		EndIf;
		
		If NOT ValueIsFilled(DefaultCompany) Then
			
			ShowMessageBox(, Nstr("pl='Powstał błąd podczas tworzenia firmy';en='An error occured while creating company'"));
			Return;
			
		EndIf;
		
		ShowValue(, DefaultCompany);
		
	EndIf;
EndProcedure

&AtServer
Function CreateDefaultCompany()
	
	NewCompany	= Catalogs.Companies.CreateItem();
		
	Try
		
		NewCompany.DataExchange.Load = True;
		NewCompany.Write();
		RefreshReusableValues();
		Return NewCompany.Ref;
		
	Except
		
		Return Undefined;
		
	EndTry;
	
EndFunction