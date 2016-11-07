#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure BeforeWrite(Cancel)
	
	If Not ValueIsFilled(ResourceValue) Then
		ResourceValue = Undefined;	
	EndIf;
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.EnterpriseResourcesKinds.CreateRecordSet();
	RecordSet.Filter.EnterpriseResource.Set(Ref);
    RecordSet.Filter.EnterpriseResourceKind.Set(Catalogs.EnterpriseResourcesKinds.AllResources);
	
	NewRecord = RecordSet.Add();
	NewRecord.EnterpriseResourceKind = Catalogs.EnterpriseResourcesKinds.AllResources;
	NewRecord.EnterpriseResource = Ref;
	RecordSet.Write();
	
EndProcedure

#EndIf