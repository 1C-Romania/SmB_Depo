
&AtClient
Procedure PresentationsTableOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		Items.PresentationsTable.CurrentData.LanguageCode = RisePresentationsReUse.GetCurrentUserLanguageCode();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("CatalogRef") Then		               
		PresentationsTable.Load(Parameters.CatalogRef.MultilingualPresentations.Unload());
	EndIf;
	
EndProcedure   

&AtClient
Procedure PresentationsTableLanguageCodeOnChange(Item)
	
	NotifyTable();
	
EndProcedure

&AtClient
Procedure PresentationsTablePresentationOnChange(Item)
	
	NotifyTable();

EndProcedure

&AtClient
Procedure NotifyTable()
	
	If  ValueIsFilled(Items.PresentationsTable.CurrentData.LanguageCode) and 
		ValueIsFilled(Items.PresentationsTable.CurrentData.LanguageCode) Then
		
		Notify("PresentationsChanged",PresentationsTable);
		
	EndIf; 
	
EndProcedure








