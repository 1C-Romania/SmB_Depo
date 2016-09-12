#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Procedure updates register data if
// applied developer changed dependencies in the overridable module.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if there
//                  is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshDataRegister(HasChanges = Undefined, CheckOnly = False) Export
	
	SetPrivilegedMode(True);
	
	If CheckOnly OR ExclusiveMode() Then
		SwitchOffSoleMode = False;
	Else
		SwitchOffSoleMode = True;
		SetExclusiveMode(True);
	EndIf;
	
	AccessRightsCorrelation = InformationRegisters.AccessRightsCorrelation.CreateRecordSet();
	
	Table = New ValueTable;
	Table.Columns.Add("SubordinateTable", New TypeDescription("String"));
	Table.Columns.Add("MasterTable",     New TypeDescription("String"));
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AccessManagement\WhenFillingOutAccessRightDependencies");
	
	For Each Handler IN EventHandlers Do
		Handler.Module.WhenFillingOutAccessRightDependencies(Table);
	EndDo;
	
	AccessManagementOverridable.WhenFillingOutAccessRightDependencies(Table);
	
	AccessRightsCorrelation = InformationRegisters.AccessRightsCorrelation.CreateRecordSet().Unload();
	For Each String IN Table Do
		NewRow = AccessRightsCorrelation.Add();
		
		MetadataObject = Metadata.FindByFullName(String.SubordinateTable);
		If MetadataObject = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred"
"in the OnFillingAccessRightDependencies procedure of the AccessManagementOverridable general module."
""
"Subordinate table ""%1"" is not found.';ru='Ошибка"
"в процедуре ПриЗаполненииЗависимостейПравДоступа общего модуля УправлениеДоступомПереопределяемый."
""
"Не найдена подчиненная таблица ""%1"".'"),
				String.SubordinateTable);
		EndIf;
		NewRow.SubordinateTable = CommonUse.MetadataObjectID(
			String.SubordinateTable);
		
		MetadataObject = Metadata.FindByFullName(String.MasterTable);
		If MetadataObject = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='An error occurred"
"in the OnFillingAccessRightDependencies procedure of the AccessManagementOverridable general module."
""
"Leading table ""%1"" is not found.';ru='Ошибка"
"в процедуре ПриЗаполненииЗависимостейПравДоступа общего модуля УправлениеДоступомПереопределяемый."
""
"Не найдена ведущая таблица ""%1"".'"),
				String.MasterTable);
		EndIf;
		NewRow.MasterTableType = CommonUse.ObjectManagerByFullName(
			String.MasterTable).EmptyRef();
	EndDo;
	
	TemporaryTablesQueryText =
	"SELECT
	|	NewData.SubordinateTable,
	|	NewData.MasterTableType
	|INTO NewData
	|FROM
	|	&AccessRightsCorrelation AS NewData";
	
	QueryText =
	"SELECT
	|	NewData.SubordinateTable,
	|	NewData.MasterTableType,
	|	&InsertFieldsRowChangeKind
	|FROM
	|	NewData AS NewData";
	
	// Prepare the selected fields with an optional filter.
	Fields = New Array;
	Fields.Add(New Structure("SubordinateTable"));
	Fields.Add(New Structure("MasterTableType"));
	
	Query = New Query;
	AccessRightsCorrelation.GroupBy("SubordinateTable, MasterTableType");
	Query.SetParameter("AccessRightsCorrelation", AccessRightsCorrelation);
	
	Query.Text = AccessManagementService.TextOfQuerySelectionChanges(
		QueryText, Fields, "InformationRegister.AccessRightsCorrelation", TemporaryTablesQueryText);
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.AccessLimitationParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = Block.Add("InformationRegister.AccessRightsCorrelation");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Data = New Structure;
		Data.Insert("ManagerRegister",      InformationRegisters.AccessRightsCorrelation);
		Data.Insert("ChangeRowsContent", Query.Execute().Unload());
		Data.Insert("CheckOnly",        CheckOnly);
		
		AccessManagementService.RefreshInformationRegister(Data, HasChanges);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		If SwitchOffSoleMode Then
			SetExclusiveMode(False);
		EndIf;
		Raise;
	EndTry;
	
	If SwitchOffSoleMode Then
		SetExclusiveMode(False);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf