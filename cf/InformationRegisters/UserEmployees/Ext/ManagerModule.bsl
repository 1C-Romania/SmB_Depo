#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Adds the record in the register by passing parameters
//
// DataMap - (Matching) Data map, where
//
// 	Key - (Catalog.Employees) An employee that is assigned to a user;
// 	Value - (Catalog.Users) A user that is associated with an employee
//
Procedure AddUsersEmployees(DataMap) Export
	
	For Each MapItem IN DataMap Do
		
		RecordManager = InformationRegisters.UserEmployees.CreateRecordManager();
		RecordManager.Employee = MapItem.Key;
		RecordManager.User = MapItem.Value;
		RecordManager.Write(True);
		
	EndDo;
	
EndProcedure // AddEmployeeUser()

#EndRegion

#EndIf