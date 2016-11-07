// Replaces account documents when report call by mutual
// settlements from receipt If receipt by order to supplier - settlement document is the purchase order
//
// Parameters:
// Parameters - FormDataStructure - Report parameters
//
&AtServer
Procedure SetSelectionReport(Parameters) Export
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("ProductionOrder") Then
		
		DocumentParameter = Parameters.Filter.ProductionOrder;
		If TypeOf(DocumentParameter) = Type("Array") Then
			DocumentType = TypeOf(DocumentParameter[0]);		
		Else
			DocumentType = TypeOf(DocumentParameter);		
		EndIf;
		
		If DocumentType <> Type("DocumentRef.ProductionOrder") Then
		
			Query = New Query("SELECT DISTINCT
			                      |	DocumentSource.BasisDocument AS ProductionOrder
			                      |FROM
			                      |	Document.InventoryAssembly AS DocumentSource
			                      |WHERE
			                      |	DocumentSource.Ref IN(&DocumentParameter)");
								  
			Query.SetParameter("DocumentParameter", DocumentParameter);
			ResultTable = Query.Execute().Unload();
			Parameters.Filter.ProductionOrder = ResultTable.UnloadColumn("ProductionOrder");			
		
		EndIf;
		
	EndIf;
	
EndProcedure // ReplaceAccountDocumentsWithSuppliers()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetSelectionReport(Parameters);
	
EndProcedure // OnCreateAtServer()

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
