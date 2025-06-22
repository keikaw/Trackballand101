logFile := A_ScriptDir "\debug_log.txt" ; スクリプトと同じディレクトリにログファイルを作成
logAdd(str) {
	FileAppend(str ,logFile)
}

; ----- 定数定義 -----
; WH_MOUSE_LL (Low-Level Mouse Hook)
Global WH_MOUSE_LL := 14
 ; マウスイベントメッセージ
Global WM_MOUSEMOVE    := 0x0200
Global WM_LBUTTONDOWN  := 0x0201
Global WM_LBUTTONUP    := 0x0202
Global WM_RBUTTONDOWN  := 0x0204
Global WM_RBUTTONUP    := 0x0205
Global WM_MBUTTONDOWN  := 0x0207
Global WM_MBUTTONUP    := 0x0208
Global WM_XBUTTONDOWN  := 0x020B
Global WM_XBUTTONUP    := 0x020C
Global WM_MOUSEWHEEL   := 0x020A
Global WM_MOUSEHWHEEL  := 0x020E

Global MouseHookHandle := 0

Global IsScrolling
Global before_pos_x
Global before_pos_y
Global initial_pos_x
Global initial_pos_y
Global before_time := 0

Global sekibun_move_pos_x := 0
Global sekibun_move_pos_y := 0

Global request := {x: 0, y: 0, mstime: 0}

; ----- 関数定義 -----
; マウスフックをインストールする関数
HookMouseCursor() {
    Global MouseHookHandle
	Global before_pos_x
	Global before_pos_y

    ; 自身のモジュールハンドルを取得 (NULL を渡すと自身のインスタンスハンドル)
    hinst := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
    MouseHookProcPtr := CallbackCreate(MouseHookProc, "F") ; "F" は Fast モード (推奨)
    MouseHookHandle := DllCall("SetWindowsHookEx", "Int", WH_MOUSE_LL, "Ptr", MouseHookProcPtr, "Ptr", hinst, "UInt", 0, "Ptr")
    if (MouseHookHandle = 0) {
        MsgBox "マウスフックのインストールに失敗しました。エラーコード: " A_LastError, "エラー", "IconStop"
        CallbackFree(MouseHookProcPtr) ; エラー時はコールバックも解放
        MouseHookEnabled := false
    }

	; 現在のカーソル位置を保存
	lpPoint := Buffer(8,0)
	DllCall("GetCursorPos", "Ptr", lpPoint.Ptr)
	x := NumGet(lpPoint.Ptr,   "Int")
	y := NumGet(lpPoint.Ptr+4, "Int")
	before_pos_x := x
	before_pos_y := y
}

; ----- 関数定義 -----
; マウスフックを再度インストールする関数
HookMouseCursor2() {
    Global MouseHookHandle

    ; 自身のモジュールハンドルを取得 (NULL を渡すと自身のインスタンスハンドル)
    hinst := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
    MouseHookProcPtr := CallbackCreate(MouseHookProc, "F") ; "F" は Fast モード (推奨)
    MouseHookHandle := DllCall("SetWindowsHookEx", "Int", WH_MOUSE_LL, "Ptr", MouseHookProcPtr, "Ptr", hinst, "UInt", 0, "Ptr")
    if (MouseHookHandle = 0) {
        MsgBox "マウスフックのインストールに失敗しました。エラーコード: " A_LastError, "エラー", "IconStop"
        CallbackFree(MouseHookProcPtr) ; エラー時はコールバックも解放
        MouseHookEnabled := false
    }
}

; マウスフックを解除する関数
UnhookMouseCursor() {
    Global MouseHookHandle
    if (MouseHookHandle != 0) {
        DllCall("UnhookWindowsHookEx", "Ptr", MouseHookHandle)
        MouseHookHandle := 0
    }
}

; マウスフックプロシージャ (コールバック関数)
; この関数が Windows によって呼び出される
MouseHookProc(nCode, wParam, lParam) {
	Global WM_MOUSEMOVE
    Global MouseHookHandle
	Global before_pos_x
	Global before_pos_y
	Global sekibun_move_pos_x
	Global sekibun_move_pos_y
	Global before_time

    ; nCode が 0 未満の場合は処理せず、次のフックに渡す
    if (nCode < 0) {
		logAdd("Hook cancel nCode " . nCode . "`n")
        return DllCall("CallNextHookEx", "Ptr", MouseHookHandle, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }
    if (wParam != WM_MOUSEMOVE) {
		logAdd( "Hook cancel wParam " . wParam . "`n")
        return DllCall("CallNextHookEx", "Ptr", MouseHookHandle, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
	}

    ; MSLLHOOKSTRUCT 構造体から情報を取得
    ; struct POINT pt;          (8 bytes)
    ; DWORD mouseData;          (4 bytes)
    ; DWORD flags;              (4 bytes)
    ; DWORD time;               (4 bytes)
    ; ULONG_PTR dwExtraInfo;    (Ptr size: 4/8 bytes)

    ; MSLLHOOKSTRUCT.pt.x
    x := NumGet(lParam + 0, "Int")
    ; MSLLHOOKSTRUCT.pt.y
    y := NumGet(lParam + 4, "Int")
    ; mouseData (ホイール回転など)
    mouseData := NumGet(lParam + 8, "UInt")
    ; flags
    flags := NumGet(lParam + 12, "UInt")

	movex := ( x - before_pos_x )
	movey := ( y - before_pos_y )
	logAdd("move:" . x . " " . y . " " . movex . " " . movey . " " . sekibun_move_pos_x . " " . sekibun_move_pos_y . " " . before_pos_x . " " . before_pos_y . "`n")

	;移動量を積分する
	sekibun_move_pos_x := sekibun_move_pos_x + movex
	sekibun_move_pos_y := sekibun_move_pos_y + movey
	time := A_TickCount
	if( (time - before_time) > 100 ) {
		; 100ms経過したら
		SendWheelFunc(movex,movey, (time - before_time) )
		sekibun_move_pos_x := 0
		sekibun_move_pos_y := 0
		before_time := time 
		return 1
	}
	if( ( abs(sekibun_move_pos_x) + abs(sekibun_move_pos_y) ) > 200 ) {
		;移動量の総和が200を超えたらスクロール処理を行う
		SendWheelFunc(sekibun_move_pos_x,sekibun_move_pos_y, (time - before_time) )
		;速い移動の時は同一方法のゲインを1/4程残す
		if( sekibun_move_pos_x > 67138560 ) {
			sekibun_move_pos_x := 67138560
		} else if ( sekibun_move_pos_x < -67138560 ) {
			sekibun_move_pos_x := -67138560
		} else {
			sekibun_move_pos_x := Floor(sekibun_move_pos_x / 4)
		}
		if( sekibun_move_pos_y > 67138560 ) {
			sekibun_move_pos_y := 67138560
		} else if ( sekibun_move_pos_y < -67138560 ) {
			sekibun_move_pos_y := -67138560
		} else {
			sekibun_move_pos_y := Floor(sekibun_move_pos_y / 4)
		}
		before_time := time 
	}
	return 1
}

; マウスカーソルを固定するホットキー (例: F1)
F1:: {
	BlockInput "MouseMoveOff"
	DllCall("user32.dll\BlockInput", "Int", 0)
	MsgBox "マウスカーソル固定を解除しました。"
}

disableToolTip() {
	ToolTip
}

; マウスの進むボタン
XButton2:: {
	Global initial_pos_x
	Global initial_pos_y
	Global before_pos_x
	Global before_pos_y
	Global IsScrolling

	; 進むボタンが押された瞬間（長押し判定用）
	if KeyWait("XButton2","T0.2") 
	{
        UnhookMouseCursor()
		BlockInput "MouseMoveOff"
		; 1 (TRUE) で入力をブロック
		;DllCall("user32.dll\BlockInput", "Int", 0)
		MouseMove(initial_pos_x, initial_pos_y)
		if ( IsScrolling == true ) {
			; スクロールモードを解除
			ToolTip "disable scroll"
			IsScrolling := false
			; 1秒後にツールチップを非表示にする
			SetTimer disableToolTip, -1000
		}
		else {
			; スクロールモードでない場合は通常処理
			Send "{XButton2}"
		}
	} else {
		; 1 (TRUE) で入力をブロック
		;DllCall("user32.dll\BlockInput", "Int", 1)
		BlockInput "MouseMove"

		; 長押しされたらスクロールモードに切り替え
		ToolTip "enable scroll"
		IsScrolling := true

		MouseGetPos &pos_x,&pos_y
		initial_pos_x := pos_x
		initial_pos_y := pos_y
        HookMouseCursor()
	}
}

CalculateAccelerationFactor(x,y,mstime) {
	if ( mstime = 0 ) {
		absx := Floor( abs(x) * 100 )
		absy := Floor( abs(y) * 100 )
	} else {
		absx := Floor( abs(x) * 100 / mstime )
		absy := Floor( abs(y) * 100 / mstime )
	}
	if ( absx == 0 ) {
		absx := 1
	}
	if ( absy == 0 ) {
		absy := 1
	}

	value := Floor((absx+absy)/2)
	if( value > 273 ) {
		value := 273
		times := Floor(value / 273)
	} else {
		times := 1
	}
	return {times: times, value: value}
}

SendWheelFuncReq(x,y,mstime) {
	Global request
	request.x      := x
	request.y      := y
	request.mstime := mstime
	
	SetTimer(RcvWheelFuncReq,-10)
}
RcvWheelFuncReq() {
	Global request
	SendWheelFunc(request.x, request.y, request.mstime )
	HookMouseCursor2()
}

; Wheelのイベントを送信
SendWheelFunc(x,y,mstime) {

	accele := CalculateAccelerationFactor(x,y,mstime)

	if ( (y==0) || (abs(x / y) > 0.7) ) {
		if (x > 0) {
			logAdd("right:" . accele.times . " "  . accele.value "`n")
			SendMsgWheelRight(accele.times,accele.value)
		} else {
			logAdd("left:" . accele.times . " "  . accele.value "`n")
			SendMsgWheelLeft(accele.times,accele.value)
		}
	} 
	if ( y != 0 ) {
		if (y > 0) {
			logAdd("down:" . accele.times . " "  . accele.value "`n")
			SendMsgWheelDown(accele.times,accele.value)
		} else { 
			logAdd("up:" . accele.times . " "  . accele.value "`n")
			SendMsgWheelUp(accele.times,accele.value)
		}
	}
}
SendWheelRight(times, value) {
	num := times * value
	str := "WheelRight " . num . "}"
	Loop num {
		Send "{WheelRight}"
		;SendEvent "{WheelRight}"
		;SendPlay "{WheelRight}"
		;MouseCLick( "WheelRight" )
	}
}
SendWheelLeft(times, value) {
	num := times * value
	str := "WheelLeft " . num . "}"
	Loop num {
		Send "{WheelLeft}"
		;SendEvent "{WheelLeft}"
		;SendPlay "{WheelLeft}"
		;MouseCLick( "WheelLeft" )
	}
}
SendWheelUp(times, value) {
	num := times * value
	str := "WheelUp " . num . "}"
	Loop num {
		Send "{WheelUp}"
		;SendEvent "{WheelUp}"
		;SendPlay "{WheelUp}"
		;MouseCLick( "WheelUp" )
	}
}
SendWheelDown(times, value) {
	num := times * value
	str := "WheelDown " . num . "}"
	Loop num {
		Send "{WheelDown}"
		;SendEvent "{WheelDown}"
		;SendPlay "{WheelDown}"
		;MouseCLick( "WheelDown" )
	}
}

SendInputWheelRight(times, value) {
	num := times * value
	str := "{vk_WheelRight " . num . "}"
	SendInput(str)
}
SendInputWheelLeft(times, value) {
	num := times * value
	str := "{vk_WheelLeft" . num . "}"
	SendInput(str)
}
SendInputWheelUp(times, value) {
	num := times * value
	str := "{vk_WheelUp " . num . "}"
	SendInput(str)
}
SendInputWheelDown(times, value) {
	num := times * value
	str := "{vk_WheelDown " . num . "}"
	SendInput(str)
}

MouseClickWheelRight(times, value) {
	num := times * value
	str := "WR"
	Loop num {
		MouseClick(str, , , 1, 0, "D", )
		MouseClick(str, , , 1, 0, "U", )
	}
}
MouseClickWheelLeft(times, value) {
	num := times * value
	str := "WL"
	Loop num {
		MouseClick(str, , , 1, 0, "D", )
		MouseClick(str, , , 1, 0, "U", )
	}
}
MouseClickWheelUp(times, value) {
	num := times * value
	str := "WU"
	Loop num {
		MouseClick(str, , , 1, 0, "D", )
		MouseClick(str, , , 1, 0, "U", )
	}
}
MouseClickWheelDown(times, value) {
	num := times * value
	str := "WD"
	Loop num {
		MouseClick(str, , , 1, 0, "D", )
		MouseClick(str, , , 1, 0, "U", )
	}
}

SendMsgWheelRight(times, value) {
    Global WM_MOUSEHWHEEL

    wheel_delta := 120 * value ; MouseClickでは不要
    CoordMode("Mouse", "Screen") ; MouseClickはScreen座標がデフォルトのため不要な場合が多いが、念のため残す

    ; WM_MOUSEHWHEELのwParamの計算 (MouseClickでは不要)
    ; 16ビット左シフトして回転量を上位ワードに格納
    wParam := wheel_delta << 16
    ; 現在のマウス座標を取得 (スクリーン座標) (MouseClickは現在のカーソル位置を使用)
    MouseGetPos(&mouseX, &mouseY, &hwnd)
    ; lParamの計算 (X座標とY座標を下位ワードと上位ワードに格納) (MouseClickでは不要)
    lParam := (mouseY << 16) | (mouseX & 0xFFFF)
    Loop times {
		;SendInput("{WheelRight}")
		;SendEvent("{WheelRight}")
        ;MouseCLick("WheelRight") ; MouseClickを使用
        PostMessage(WM_MOUSEHWHEEL, wParam, lParam, hwnd) ; PostMessageはコメントアウト
    }
    CoordMode("Mouse", "Window") ; 元に戻す
}

SendMsgWheelLeft(times, value) {
    Global WM_MOUSEHWHEEL

    wheel_delta := (-120) * value ; MouseClickでは不要
    CoordMode("Mouse", "Screen") ; MouseClickはScreen座標がデフォルトのため不要な場合が多いが、念のため残す

    ; WM_MOUSEHWHEELのwParamの計算 (MouseClickでは不要)
    ; 16ビット左シフトして回転量を上位ワードに格納
    wParam := wheel_delta << 16
    ; 現在のマウス座標を取得 (スクリーン座標) (MouseClickは現在のカーソル位置を使用)
    MouseGetPos(&mouseX, &mouseY, &hwnd)
    ; lParamの計算 (X座標とY座標を下位ワードと上位ワードに格納) (MouseClickでは不要)
    lParam := (mouseY << 16) | (mouseX & 0xFFFF)
    Loop times {
		;SendInput("{WheelLeft}")
		;SendEvent("{WheelLeft}")
        ;MouseCLick("WheelLeft") ; MouseClickを使用
        PostMessage(WM_MOUSEHWHEEL, wParam, lParam, hwnd) ; PostMessageはコメントアウト
    }

    CoordMode("Mouse", "Window") ; 元に戻す
}

SendMsgWheelUp(times, value) {
    Global WM_MOUSEWHEEL

    wheel_delta := 120 * value ; MouseClickでは不要
    CoordMode("Mouse", "Screen") ; MouseClickはScreen座標がデフォルトのため不要な場合が多いが、念のため残す

    ; WM_MOUSEWHEELのwParamの計算 (MouseClickでは不要)
    ; 16ビット左シフトして回転量を上位ワードに格納
    wParam := wheel_delta << 16
    ; 現在のマウス座標を取得 (スクリーン座標) (MouseClickは現在のカーソル位置を使用)
    MouseGetPos(&mouseX, &mouseY, &hwnd)
    ; lParamの計算 (X座標とY座標を下位ワードと上位ワードに格納) (MouseClickでは不要)
    lParam := (mouseY << 16) | (mouseX & 0xFFFF)
    Loop times {
		;SendInput("{WheelUp}")
		;SendEvent("{WheelUp}")
        ;MouseCLick("WheelUp") ; MouseClickを使用
        PostMessage(WM_MOUSEWHEEL, wParam, lParam, hwnd) ; PostMessageはコメントアウト
    }

    CoordMode("Mouse", "Window") ; 元に戻す
}

SendMsgWheelDown(times, value) {
    Global WM_MOUSEWHEEL

    wheel_delta := (-120) * value ; MouseClickでは不要
    CoordMode("Mouse", "Screen") ; MouseClickはScreen座標がデフォルトのため不要な場合が多いが、念のため残す

    ; WM_MOUSEWHEELのwParamの計算 (MouseClickでは不要)
    ; 16ビット左シフトして回転量を上位ワードに格納
    wParam := wheel_delta << 16
    ; 現在のマウス座標を取得 (スクリーン座標) (MouseClickは現在のカーソル位置を使用)
    MouseGetPos(&mouseX, &mouseY, &hwnd)
    ; lParamの計算 (X座標とY座標を下位ワードと上位ワードに格納) (MouseClickでは不要)
    lParam := (mouseY << 16) | (mouseX & 0xFFFF)
    Loop times {
		;SendInput("{WheelDown}")
		;SendEvent("{WheelDown}")
        ;MouseCLick("WheelDown") ; MouseClickを使用
        PostMessage(WM_MOUSEWHEEL, wParam, lParam, hwnd) ; PostMessageはコメントアウト
    }

    CoordMode("Mouse", "Window") ; 元に戻す
}

;F2::
;{
;    ; すべてのウィンドウのIDリストを取得
;    WindowList := WinGetList()
;
;    ; 結果を格納する文字列変数
;    Output := "現在開いているウィンドウ一覧:`n`n"
;
;    ; 各ウィンドウのIDをループ処理
;    For WindowID in WindowList
;    {
;        ; ウィンドウのタイトルを取得
;        WinTitle := WinGetTitle(WindowID)
;        ; ウィンドウのクラス名を取得
;        WinClass := WinGetClass(WindowID)
;        ; ウィンドウの実行ファイル名を取得 (WinGetProcessNameはv2.0.12以降)
;        WinExe := WinGetProcessName(WindowID)
;
;        Output .= "ID: " WindowID "`n"
;        Output .= "タイトル: " WinTitle "`n"
;        Output .= "クラス: " WinClass "`n"
;        Output .= "実行ファイル: " WinExe "`n"
;        Output .= "---------------------------------`n"
;    }
;
;    ; 結果をMsgBoxで表示
;    MsgBox(Output) ; 幅と高さを指定して見やすくする
;}
