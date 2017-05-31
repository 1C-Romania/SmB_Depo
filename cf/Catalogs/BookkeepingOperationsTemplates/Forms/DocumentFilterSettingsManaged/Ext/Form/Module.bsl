#Region BaseFormsProcedures
&AtClient
Procedure OnOpen(Cancel)
	CopyFormData(FormOwner.Object, Object);
	OnOpenAtServer();	
EndProcedure
#EndRegion

#Region FormsCommands
&AtClient
Procedure SaveFilterSettings(Command)
	Close(New Structure("IsChanged, FilterAsXML", True, GetFilterAsXML()));
EndProcedure
#EndRegion

#Region Other
&AtServer
Function GetFilterAsXML()
	Return Common.SerializeObject(DataCompositionSettingsComposer.Settings.Filter);
EndFunction

&AtServer
Function OnOpenAtServer()
	CatalogObject = FormDataToValue(Object, Type("CatalogObject.BookkeepingOperationsTemplates"));
	DataCompositionSettingsComposer = CatalogObject.ApplyDocumentBaseTableChange("", Enums.BookkeepingOperationTemplateTableKind.DocumentRecords);	
	If NOT IsBlankString(Object.FilterAsXML) Then		
		TemplateReports.CopyItems(DataCompositionSettingsComposer.Settings.Filter, Common.GetObjectFromXML(Object.FilterAsXML, Type("DataCompositionFilter")), True, True);		
	EndIf;		
EndFunction

#EndRegion





