Procedure ClearRegisterRecordsForObject(Object) Export
	
	For Each RecordSet In Object.RegisterRecords Do
		RecordSet.Clear();
	EndDo;	
	
EndProcedure	