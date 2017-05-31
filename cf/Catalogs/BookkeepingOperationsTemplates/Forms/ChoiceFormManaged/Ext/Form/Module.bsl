
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	//DocumentsFormAtServer.OnCreateAtServer(ThisForm, Cancel, StandardProcessing);
	FormsAtServer.CatalogFormOnCreateAtServer(ThisForm, Cancel, StandardProcessing);
	
	SuitableOperationsList = New ValueList;
	If Parameters.Property("DocumentFilter") Then
		If Parameters.DocumentFilter<>Undefined Then
			SuitableOperationsList = BookkeepingCommon.GetListOfAvailableBookkeepingOperationTemplates(Parameters.DocumentFilter);	
			DataCompositionAtClientAtServer.SetUserSettingFilter(ThisForm.List.SettingsComposer.UserSettings, "DocumentBaseType", TypeOf(Parameters.DocumentFilter), True,DataCompositionComparisonType.Equal);						
		Else	
			DataCompositionAtClientAtServer.SetUserSettingFilter(ThisForm.List.SettingsComposer.UserSettings, "DocumentBase", Undefined, False,DataCompositionComparisonType.NotEqual);						
		EndIf;
		NotHierarchicalList = True;		
	Else
		If Parameters.Property("Filter_DocumentBase") AND Parameters.Filter_DocumentBase=Undefined Then
			DataCompositionAtClientAtServer.SetUserSettingFilter(ThisForm.List.SettingsComposer.UserSettings, "DocumentBase", Undefined, False,DataCompositionComparisonType.Equal);
		EndIf			
	EndIf;
	Items.List.RowPictureDataPath = "List.PictureIndex";
	Items.List.RowsPicture=PictureLib.BookkeepingTemplates;

	List.Parameters.SetParameterValue("SuitableOperationsList",SuitableOperationsList);	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormsAtClient.CatalogListFormOnOpen(ThisForm, Cancel);
	
	If NotHierarchicalList Then
		Items.List.Representation=TableRepresentation.List;	
	EndIf;
EndProcedure

