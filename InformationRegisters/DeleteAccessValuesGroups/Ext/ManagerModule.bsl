#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Handler of the infobase update.
Procedure MoveDataToNewTable() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.DeleteAccessValuesGroups AS DeleteAccessValuesGroups";
	
	If Query.Execute().IsEmpty() Then
		Return;
	EndIf;
	
	Query.SetParameter("OwnerTypes",
		AccessManagementServiceReUse.Parameters().PossibleRightsForObjectRightsSettings.OwnerTypes);
	
	Query.Text =
	"SELECT
	|	DeleteAccessValuesGroups.AccessValue AS Object,
	|	DeleteAccessValuesGroups.AccessValuesGroup AS Parent,
	|	DeleteAccessValuesGroups.InheritParentsRights AS Inherit
	|FROM
	|	InformationRegister.DeleteAccessValuesGroups AS DeleteAccessValuesGroups
	|		INNER JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		ON (DeleteAccessValuesGroups.AccessValue = DeleteAccessValuesGroups.AccessValuesGroup)
	|			AND (DeleteAccessValuesGroups.InheritParentsRights = FALSE)
	|			AND (VALUETYPE(DeleteAccessValuesGroups.AccessValue) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
	|			AND (MetadataObjectIDs.EmptyRefValue IN (&OwnerTypes))";
	
	BeginTransaction();
	Try
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			RecordSet = InformationRegisters.ObjectRightsSettingsInheritance.CreateRecordSet();
			RecordSet.Load(QueryResult.Unload());
			RecordSet.Write();
		EndIf;
		
		RecordSet = InformationRegisters.DeleteAccessValuesGroups.CreateRecordSet();
		RecordSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Handler of the infobase update.
Procedure ClearRegister() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.DeleteAccessValuesGroups AS DeleteAccessValuesGroups";
	
	If Query.Execute().IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.DeleteAccessValuesGroups.CreateRecordSet();
	RecordSet.Write();
	
EndProcedure

#EndRegion

#EndIf