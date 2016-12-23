#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	Cancel = True;
	ShowMessageBox(, NStr("en='Data processor is not aimed for being used directly';ru='Обработка не предназначена для непосредственного использования.'"));
EndProcedure

#EndRegion













