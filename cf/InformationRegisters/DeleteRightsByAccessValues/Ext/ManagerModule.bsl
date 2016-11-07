#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Handler of the infobase update.
Procedure MoveDataToNewTable() Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.ObjectRightsSettings AS RightsByAccessValues
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DeleteRightsByAccessValues.AccessValue AS Object,
	|	DeleteRightsByAccessValues.User,
	|	DeleteRightsByAccessValues.Right,
	|	MAX(DeleteRightsByAccessValues.Prohibited) AS RightDenied,
	|	MAX(DeleteRightsByAccessValues.SpreadInHierarchy) AS InheritanceAllowed
	|FROM
	|	InformationRegister.DeleteRightsByAccessValues AS DeleteRightsByAccessValues
	|
	|GROUP BY
	|	DeleteRightsByAccessValues.AccessValue,
	|	DeleteRightsByAccessValues.User,
	|	DeleteRightsByAccessValues.Right";
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ObjectRightsSettings");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem = Block.Add("InformationRegister.DeleteRightsByAccessValues");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		ResultsOfQuery = Query.ExecuteBatch();
		
		If ResultsOfQuery[0].IsEmpty()
		   AND Not ResultsOfQuery[1].IsEmpty() Then
			
			RecordSet = InformationRegisters.ObjectRightsSettings.CreateRecordSet();
			RecordSet.Load(ResultsOfQuery[1].Unload());
			RecordSet.Write();
			
			RecordSet = InformationRegisters.DeleteRightsByAccessValues.CreateRecordSet();
			RecordSet.Write();
			
			InformationRegisters.ObjectRightsSettings.UpdateAuxiliaryRegisterData();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf