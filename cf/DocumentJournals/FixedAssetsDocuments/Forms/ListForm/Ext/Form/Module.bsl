//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS   
//

&AtServer
// Procedure - form event handler OnCreateAtServer
// 
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		
		Return;
		
	EndIf;
	
	For Each String IN Metadata.DocumentJournals.FixedAssetsDocuments.RegisteredDocuments Do
		
		Items.DocumentType.ChoiceList.Add(String.Synonym, String.Synonym);
		DocumentTypes.Add(String.Synonym, String.Name);
		
	EndDo;
	
	If Parameters <> Undefined
		AND Parameters.Property("FixedAsset") Then
		
		FixedAsset = Parameters.FixedAsset;
		
	EndIf;
	
	List.Parameters.SetParameterValue("FixedAsset", FixedAsset);
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company = Settings.Get("Company");
	DocumentTypePresentation = Settings.Get("DocumentTypePresentation");
	
	If Parameters <> Undefined
	   AND Parameters.Property("FixedAsset") Then
		Settings.Delete("FixedAsset");
		Settings.Insert("FixedAsset", Parameters.FixedAsset);
	EndIf;
	
	FixedAsset = Settings.Get("FixedAsset");
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	List.Parameters.SetParameterValue("FixedAsset", FixedAsset);
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	SmallBusinessClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
		
EndProcedure // OnLoadDataFromSettingsAtServer()

&AtClient
// Procedure - event handler OnChange of attribute DocumentType.
// 
Procedure DocumentTypeOnChange(Item)
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	SmallBusinessClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute FixedAsset.
// 
Procedure FixedAssetOnChange(Item)
	
	List.Parameters.SetParameterValue("FixedAsset", FixedAsset);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company attribute.
// 
Procedure CompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company))
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ValueIsFilled(DocumentType) Then
		
		Cancel = True;
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("Company", Company);
		
		OpenForm("Document." + DocumentType + ".ObjectForm", New Structure("FillingValues", ParametersStructure));
		
	EndIf; 
	
EndProcedure





















