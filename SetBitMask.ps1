# Check administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell "-File `"$PSCommandPath`"" -Verb RunAs
    exit
}

function Console
{
    param ([Switch]$Show,[Switch]$Hide)
    if (-not ("Console.Window" -as [type])) { 

        Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        '
    }

    if ($Show)
    {
        $consolePtr = [Console.Window]::GetConsoleWindow()

        $null = [Console.Window]::ShowWindow($consolePtr, 5)
    }

    if ($Hide)
    {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        $null = [Console.Window]::ShowWindow($consolePtr, 0)
    }
}

Add-Type -AssemblyName System.Windows.Forms

# config inicial
$global:lsb = $true
$global:digitgroup = $true
$global:desiredLength = 16

function Convert-HexToDec ($hex) {
    try {
        if ([string]::IsNullOrEmpty($hex)) {
            return $hex
        }

        # Convertir el hex a un número decimal
        $dec = [Convert]::ToInt64($hex, 16)

        # Devolver el valor como un string para mantener los ceros a la izquierda
        return $dec
    } catch {
        return
    }
}

function Convert-DecToHex ($dec) {
    try {

        if ([string]::IsNullOrEmpty($dec)) {
            return $dec
        }

        # Convertir el decimal a hexadecimal
        $hex = "{0:X}" -f [int64]$dec
        return $hex
    } catch {
        return
    }
}

function Convert-DecToBin ($dec) {
    try {

        if ([string]::IsNullOrEmpty($dec)) {
            return $dec
        }

        # Convertir el número decimal a binario
         $bin = [Convert]::ToString($dec, 2)

        return $bin
    }
    catch {
        return
    }
}

function Convert-BinToDec ($bin) {
    try {

        if ([string]::IsNullOrEmpty($bin)) {
            return $bin
        }

        # Convertir el binario a decimal
        return [Convert]::ToInt64($bin, 2)
    } catch {
        return
    }
}

function Convert-HexToBin ($hex) {
    try {

        if ([string]::IsNullOrEmpty($hex)) {
            return $hex
        }

        # Convertir el hex a binario
        $bin = [Convert]::ToString([Convert]::ToInt64($hex, 16), 2)

        $desiredLength = $hex.Length * 2

        if ($global:digitgroup) {
            $desiredLength = $hex.Length * 4
            
        }

        $bin = $bin.PadLeft($desiredLength, '0')

        return $bin
    } catch {
        return
    }
}

function Convert-BinToHex ($bin) {
    try {
        if ([string]::IsNullOrEmpty($bin)) {
            return $bin
        }

        # Convertir la cadena binaria a un número entero
        $dec = [Convert]::ToInt64($bin, 2)

        # Convertir a hexadecimal sin ceros a la izquierda
        $hex = "{0:X}" -f $dec

         $desiredLength = [math]::Ceiling($bin.Length / 2.0)

        if ($global:digitgroup) {
            $desiredLength = [math]::Ceiling($bin.Length / 4.0)
            
        }

        $hex = $hex.PadLeft($desiredLength, '0')

        return $hex
    }
    catch {
        return
    }
}

# función para actualizar valores
function Update-Values {
    param (
        [string]$source,
        [string]$value
    )

    if ($source -eq 'Hex') {
            $textBoxDec.Text = Convert-HexToDec -hex $value
            $textBoxBinary.Text = Convert-HexToBin -hex $value
            Update-BitPairs -value $textBoxBinary.Text
    } elseif ($source -eq 'Dec') {
            $textBoxHex.Text = Convert-DecToHex -dec $value
            $textBoxBinary.Text = Convert-DecToBin -dec $value
            Update-BitPairs -value $textBoxBinary.Text
    } elseif ($source -eq 'Binary') {
            $textBoxDec.Text = Convert-BinToDec -bin $value
            $textBoxHex.Text = Convert-BinToHex -bin $value
            Update-BitPairs -value $value
    }
}

function Update-BitPairs {
    param (
        [string]$value
    )

    # Guardar el índice del TextBox actualmente enfocado
    $focusedTextBox = $global:textBoxPairs | Where-Object { $_.Focused }
    $focusedIndex = $global:textBoxPairs.IndexOf($focusedTextBox)

    # Dividir el valor binario en pares de bits y actualizar los TextBoxes correspondientes
    for ($i = 0; $i -lt $global:textBoxPairs.Count; $i++) {
        if ($i * 2 -lt $value.Length) {
            # Verificar si hay suficientes caracteres para extraer una subcadena de longitud 2
            if ($i * 2 + 2 -le $value.Length) {
                $global:textBoxPairs[$i].Text = $value.Substring($i * 2, 2)
            } else {
                # Si no hay suficientes caracteres, establecer el TextBox en blanco o manejar según lo necesario
                $global:textBoxPairs[$i].Text = ""
            }
        } else {
            # Si el índice es mayor o igual que la longitud del valor binario, establecer en blanco o manejar según lo necesario
            $global:textBoxPairs[$i].Text = ""
        }
    }

    # Restaurar el foco al TextBox que estaba enfocado anteriormente
    if ($focusedIndex -ne -1) {
        $global:textBoxPairs[$focusedIndex].Focus()
    }
}

# función para crear y mostrar pares de bits y sumas
function Create-BitGroups {
    param (
        [int]$numGroups,
        [System.Windows.Forms.Form]$form
    )

    # Limpiar los textbox anteriores si existen
    foreach ($lpair in $global:labelPairs) {
        $lpair.Dispose()
    }

    # Limpiar los textbox anteriores si existen
    foreach ($pair in $global:textBoxPairs) {
        $pair.Dispose()
    }

    $global:labelPairs.Clear()
    $global:textBoxPairs.Clear()

    $left = 25
    $top = 30
    $bitWidth = 50
    $textBoxWidth = 20 
    $textBoxHeight = 20

    for ($i = 0; $i -lt $numGroups; $i++) {
        # Calcular posiciones para cada par de bits
        $labelIndex1 = $i * 2
        $labelIndex2 = $labelIndex1 + 1

        # Ajustar los índices según el endianess seleccionado
        if ($global:lsb -and $global:desiredLength -eq 16) {
            $labelIndex1 = 31 - $labelIndex1
            $labelIndex2 = 31 - $labelIndex2
        } elseif ($global:lsb -and $global:desiredLength -eq 32) {
            $labelIndex1 = 63 - $labelIndex1
            $labelIndex2 = 63 - $labelIndex2
        }

        # crear pares de bits
        $labelPair = New-Object System.Windows.Forms.Label
        $labelPair.Name = "LabelPair_$i"
        $labelPair.Text = "${labelIndex1}:${labelIndex2}"
        $labelPair.AutoSize = $true
        $labelPair.Location = New-Object System.Drawing.Point($left, $top)
        $labelPair.BackColor = [System.Drawing.Color]::Transparent
        $labelPair.ForeColor = [System.Drawing.Color]::White
        $form.Controls.Add($labelPair)
        $global:labelPairs.Add($labelPair)

        # Crear TextBox debajo de la etiqueta
        $textBoxPair = New-Object System.Windows.Forms.TextBox
        $textBoxPair.Size = New-Object System.Drawing.Size($textBoxWidth, $textBoxHeight)
        $textBoxPair.Location = New-Object System.Drawing.Point(($left + 1), ($top + 20))  # Espacio entre la etiqueta y el TextBox
        $textBoxPair.MaxLength = 2
        $textBoxPair.Name = "TextBoxPair_$i"
        $textBoxPair.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $textBoxPair.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 44)
        $textBoxPair.ForeColor = [System.Drawing.Color]::White

        # Agregar el evento TextChanged
        $textBoxPair.Add_TextChanged({
            # Actualizar $binaryValue con los valores actuales de todos los TextBox
            $binaryValue = ""
            foreach ($pair in $global:textBoxPairs) {
                $binaryValue += $pair.Text
            }

            if ($this.Focused) {
                # Actualizar los TextBox de Binario, Decimal y Hexadecimal
                $textBoxBinary.Text = $binaryValue
                $textBoxDec.Text = Convert-BinToDec -bin $binaryValue
                $textBoxHex.Text = Convert-BinToHex -bin $binaryValue
            }
            
            # Mover el foco al siguiente TextBox si el actual tiene un par de caracteres y está enfocado
            if ($this.Text.Length -eq 2 -and $this.Focused) {
                $actIndex = $global:textBoxPairs.IndexOf($this)
                if ($actIndex -lt ($global:textBoxPairs.Count - 1)) {
                    $nextIndex = $actIndex + 1
                    $global:textBoxPairs[$nextIndex].Focus()
                }
            }
        })

        $textBoxPair.Add_KeyDown({
            param($sender, $e)

            # Verificar si se presionó backspace
            if ($e.KeyCode -eq "Back") {
                # Manejar la tecla de retroceso para borrar y mover el foco al TextBox anterior si es el primer carácter
                if ($sender.Text.Length -eq 0) {
                    $prevIndex = [math]::Max($global:textBoxPairs.IndexOf($sender) - 1, 0)
                    $global:textBoxPairs[$prevIndex].Focus()
                }

                # Actualizar $binaryValue con los valores actuales de todos los TextBox
                $binaryValue = ""
                foreach ($pair in $global:textBoxPairs) {
                    $binaryValue += $pair.Text
                }

                # Actualizar los TextBox de Binario, Decimal y Hexadecimal
                $textBoxBinary.Text = $binaryValue
                $textBoxDec.Text = Convert-BinToDec -bin $binaryValue
                $textBoxHex.Text = Convert-BinToHex -bin $binaryValue
            }

            # Verificar si se presionó Shift + Flecha Derecha
            elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Right) {
                $nextIndex = [math]::Min($global:textBoxPairs.IndexOf($sender) + 1, $global:textBoxPairs.Count - 1)
                $nextTextBox = $global:textBoxPairs[$nextIndex]
                $nextTextBox.Focus()
                $nextTextBox.SelectAll() # Seleccionar todo el texto en el siguiente TextBox
                $e.Handled = $true
            }

            # Verificar si se presionó Shift + Flecha Izquierda
            elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Left) {
                $prevIndex = [math]::Max($global:textBoxPairs.IndexOf($sender) - 1, 0)
                $prevTextBox = $global:textBoxPairs[$prevIndex]
                $prevTextBox.Focus()
                $prevTextBox.SelectAll() # Seleccionar todo el texto en el TextBox anterior
                $e.Handled = $true
            }

            if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::Back) {
                $textBox = $sender
                $cursorPos = $textBox.SelectionStart

                if ($cursorPos -gt 0) {
                    $textBox.Text = $textBox.Text.Substring($cursorPos) # Mantiene solo el texto a la derecha del cursor
                    $textBox.SelectionStart = 0 # Mueve el cursor al inicio del texto
                    $e.Handled = $true
                }
            }

            if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::Back) {
                foreach ($pair in $global:textBoxPairs) {
                    $pair.Clear()
                }
    
                # Regresar al TextBox en el índice 1, si existe
                if ($global:textBoxPairs.Count -gt 1) {
                    $global:textBoxPairs[0].Focus() 
                    $global:textBoxPairs[0].SelectAll()
                }

                                # Actualizar $binaryValue con los valores actuales de todos los TextBox
                $binaryValue = ""
                foreach ($pair in $global:textBoxPairs) {
                    $binaryValue += $pair.Text
                }

                # Actualizar los TextBox de Binario, Decimal y Hexadecimal
                $textBoxBinary.Text = $binaryValue
                $textBoxDec.Text = Convert-BinToDec -bin $binaryValue
                $textBoxHex.Text = Convert-BinToHex -bin $binaryValue

                $e.Handled = $true
            }
        })

        $textBoxPair.Add_KeyPress({
            param($sender, $e)
            if ($e.KeyChar -ne '1' -and $e.KeyChar -ne '0' -and $e.KeyChar -ne [char]8) {
                $e.Handled = $true
            }
        })

        $form.Controls.Add($textBoxPair)
        $global:textBoxPairs.Add($textBoxPair)

        # Ajustar posición izquierda para el próximo par de bits
        $left += $bitWidth

        # Saltar a la siguiente línea después de 8 pares de bits
        if (($i + 1) % 8 -eq 0) {
            $left = 25
            $top += 70
        }
    }
}

# lista global BitPairs
$global:textBoxPairs = New-Object System.Collections.Generic.List[System.Windows.Forms.TextBox]
$global:labelPairs = New-Object System.Collections.Generic.List[System.Windows.Forms.Label]

# crear form
Console -Hide
[System.Windows.Forms.Application]::EnableVisualStyles();
$form = New-Object System.Windows.Forms.Form
$form.Text = "SetBitmask"
$form.Size = New-Object System.Drawing.Size(435, 485)
$form.StartPosition = "CenterScreen"
$form.MaximizeBox = $false
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.Add_Paint({
    param (
        [object]$sender,
        [System.Windows.Forms.PaintEventArgs]$e
    )
    $rect = New-Object System.Drawing.Rectangle(0, 0, $sender.Width, $sender.Height)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(44, 44, 44),   # Color negro
        [System.Drawing.Color]::FromArgb(99, 99, 99),# Color gris oscuro
        [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
    $e.Graphics.FillRectangle($brush, $rect)
})

# crear los pares de bits
Create-BitGroups -numGroups 16 -form $form

# leer ceros a la izquierda
$chkbits = New-Object System.Windows.Forms.CheckBox
$chkbits.Text = "DigitGroup"
$chkbits.AutoSize = $true
$chkbits.Checked = $global:digitgroup
$chkbits.Location = New-Object System.Drawing.Point(40, 300)
$chkbits.BackColor = [System.Drawing.Color]::Transparent
$chkbits.ForeColor = [System.Drawing.Color]::White
$chkbits.Add_CheckedChanged({
    if ($chkbits.Checked) {
        $global:digitgroup = $true
    } else {
        $global:digitgroup = $false
    }

    Update-Values -source 'Hex' -value $textBoxHex.Text
})
$form.Controls.Add($chkbits)

# Checkbox modo de bits
$chk64 = New-Object System.Windows.Forms.CheckBox
$chk64.Text = "BitMode"
$chk64.AutoSize = $true
$chk64.Location = New-Object System.Drawing.Point(170, 300)
$chk64.ThreeState = $true
$chk64.BackColor = [System.Drawing.Color]::Transparent
$chk64.ForeColor = [System.Drawing.Color]::White
$chk64.Add_CheckStateChanged({
    if ($chk64.CheckState -eq [System.Windows.Forms.CheckState]::Checked) {
        $global:desiredLength = 8  # Estado Unchecked -> 16 bits
    } elseif ($chk64.CheckState -eq [System.Windows.Forms.CheckState]::Unchecked) {
        $global:desiredLength = 16  # Estado Checked -> 32 bits
    } elseif ($chk64.CheckState -eq [System.Windows.Forms.CheckState]::Indeterminate) {
        $global:desiredLength = 32  # Estado Indeterminate -> 64 bits
    }
    Create-BitGroups -numGroups $global:desiredLength -form $form
    Update-Values -source 'Binary' -value $textBoxBinary.Text
})
$form.Controls.Add($chk64)


# Checkbox para cambiar a lsb
$chklsb = New-Object System.Windows.Forms.CheckBox
$chklsb.Text = "MsbToLsb"
$chklsb.AutoSize = $true
$chklsb.Checked = $global:lsb
$chklsb.Location = New-Object System.Drawing.Point(280, 300)
$chklsb.BackColor = [System.Drawing.Color]::Transparent
$chklsb.ForeColor = [System.Drawing.Color]::White
$chklsb.Add_CheckedChanged({
    if ($chklsb.Checked) {
        $global:lsb = $true
    } else {
        $global:lsb = $false
    }

    # Recrear los bit groups con el nuevo endianess
    Create-BitGroups -numGroups $global:desiredLength -form $form
    Update-Values -source 'Binary' -value $textBoxBinary.Text
})
$form.Controls.Add($chklsb)



# valor hex
$labelHex = New-Object System.Windows.Forms.Label
$labelHex.Text = "Hexadecimal"
$labelHex.Size = New-Object System.Drawing.Size(70, 15)
$labelHex.Location = New-Object System.Drawing.Point(10, 340)
$labelHex.BackColor = [System.Drawing.Color]::Transparent
$labelHex.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($labelHex)

$textBoxHex = New-Object System.Windows.Forms.TextBox
$textBoxHex.Size = New-Object System.Drawing.Size(190, 10)
$textBoxHex.Location = New-Object System.Drawing.Point(10, 360)
$textBoxHex.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$textBoxHex.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 44)
$textBoxHex.ForeColor = [System.Drawing.Color]::White
$textBoxHex.Add_KeyPress({
    param($sender, $e)
    if ((($e.KeyChar -lt '0' -or $e.KeyChar -gt '9') -and
         ($e.KeyChar -lt 'A' -or $e.KeyChar -gt 'F') -and
         ($e.KeyChar -lt 'a' -or $e.KeyChar -gt 'f')) -and
         $e.KeyChar -ne [char][System.Windows.Forms.Keys]::Back -and
         $e.KeyChar -ne [System.Windows.Forms.Keys]::Right -and
         $e.KeyChar -ne [System.Windows.Forms.Keys]::Left) {
        $e.Handled = $true
    }
})
$textBoxHex.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::C) {
        # Ctrl+C
        $textBoxHex.Copy()
    }
    elseif ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::V) {
        # Ctrl+V
        $textBoxHex.Paste()
        Update-Values -source 'Hex' -value $textBoxHex.Text
        $e.Handled = $true
    }

    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::Back) {
        $textBox = $sender
        $cursorPos = $textBox.SelectionStart

        if ($cursorPos -gt 0) {
            $textBox.Text = $textBox.Text.Substring($cursorPos) # Mantiene solo el texto a la derecha del cursor
            $textBox.SelectionStart = 0 # Mueve el cursor al inicio del texto
            $e.Handled = $true
        }
    }
})
$textBoxHex.Add_TextChanged({
    if ($textBoxHex.Focused) {
        Update-Values -source 'Hex' -value $textBoxHex.Text
    }
})
$form.Controls.Add($textBoxHex)

# valor dec
$labelDec = New-Object System.Windows.Forms.Label
$labelDec.Text = "Decimal"
$labelDec.Size = New-Object System.Drawing.Size(70, 15)
$labelDec.Location = New-Object System.Drawing.Point(215, 340)
$labelDec.BackColor = [System.Drawing.Color]::Transparent
$labelDec.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($labelDec)

$textBoxDec = New-Object System.Windows.Forms.TextBox
$textBoxDec.Size = New-Object System.Drawing.Size(190, 10)
$textBoxDec.Location = New-Object System.Drawing.Point(215, 360)
$textBoxDec.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$textBoxDec.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 44)
$textBoxDec.ForeColor = [System.Drawing.Color]::White
$textBoxDec.Add_KeyPress({
    param($sender, $e)
    if ($e.KeyChar -lt '0' -or $e.KeyChar -gt '9' -and
    $e.KeyChar -ne [char][System.Windows.Forms.Keys]::Back -and
    $e.KeyChar -ne [System.Windows.Forms.Keys]::Right -and
    $e.KeyChar -ne [System.Windows.Forms.Keys]::Left) {
        $e.Handled = $true
    }
})
$textBoxDec.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::C) {
        # Ctrl+C
        $textBoxDec.Copy()
    }
    elseif ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::V) {
        # Ctrl+V
        $textBoxDec.Paste()
        Update-Values -source 'Dec' -value $textBoxDec.Text
        $e.Handled = $true
    }

    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::Back) {
        $textBox = $sender
        $cursorPos = $textBox.SelectionStart

        if ($cursorPos -gt 0) {
            $textBox.Text = $textBox.Text.Substring($cursorPos) # Mantiene solo el texto a la derecha del cursor
            $textBox.SelectionStart = 0 # Mueve el cursor al inicio del texto
            $e.Handled = $true
        }
    }
})
$textBoxDec.Add_TextChanged({
    if ($textBoxDec.Focused) {
        Update-Values -source 'Dec' -value $textBoxDec.Text
    }
})
$form.Controls.Add($textBoxDec)

# valor binario
$labelBitmask = New-Object System.Windows.Forms.Label
$labelBitmask.Text = "Binary"
$labelBitmask.Size = New-Object System.Drawing.Size(70, 15)
$labelBitmask.Location = New-Object System.Drawing.Point(10, 400)
$labelBitmask.BackColor = [System.Drawing.Color]::Transparent
$labelBitmask.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($labelBitmask)

$textBoxBinary = New-Object System.Windows.Forms.TextBox
$textBoxBinary.Size = New-Object System.Drawing.Size(395, 10)
$textBoxBinary.Location = New-Object System.Drawing.Point(10, 420)
$textBoxBinary.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$textBoxBinary.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 44)
$textBoxBinary.ForeColor = [System.Drawing.Color]::White
$textBoxBinary.MaxLength = 64 #64bits
$textBoxBinary.Add_KeyDown({
    param($sender, $e)
    if (-not ($e.KeyCode -eq [System.Windows.Forms.Keys]::D0 -or
    $e.KeyCode -eq [System.Windows.Forms.Keys]::D1 -or
    $e.KeyCode -eq [System.Windows.Forms.Keys]::NumPad0 -or
    $e.KeyCode -eq [System.Windows.Forms.Keys]::NumPad1 -or
    $e.KeyCode -eq [System.Windows.Forms.Keys]::Back -or 
    $e.KeyCode -eq [System.Windows.Forms.Keys]::Right -or
    $e.KeyCode -eq [System.Windows.Forms.Keys]::Left)) {
        $e.SuppressKeyPress = $true
    }
})
$textBoxBinary.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::C) {
        # Ctrl+C
        $textBoxBinary.Copy()
    }
    elseif ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::V) {
        # Ctrl+V
        $textBoxBinary.Paste()
        Update-Values -source 'Binary' -value $textBoxBinary.Text
        $e.Handled = $true
    }

    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::Back) {
        $textBox = $sender
        $cursorPos = $textBox.SelectionStart

        if ($cursorPos -gt 0) {
            $textBox.Text = $textBox.Text.Substring($cursorPos) # Mantiene solo el texto a la derecha del cursor
            $textBox.SelectionStart = 0 # Mueve el cursor al inicio del texto
            $e.Handled = $true
        }
    }
})
$textBoxBinary.Add_TextChanged({
    if ($textBoxBinary.Focused) {
        Update-Values -source 'Binary' -value $textBoxBinary.Text
    }
})
$form.Controls.Add($textBoxBinary)

# iniciar form
$form.ShowDialog()
