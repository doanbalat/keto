import 'package:flutter/material.dart';

class BasicFormulasPage extends StatelessWidget {
  const BasicFormulasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Các Công Thức Cơ Bản'),
        backgroundColor: Colors.black26,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFormulaCardWithWidget(
            title: '1. Lợi Nhuận (Profit)',
            formulaWidget: _buildSimpleFormula(
              left: 'Lợi nhuận',
              operator: '=',
              right: 'Doanh thu − Chi phí',
            ),
            description:
                'Công thức tính lợi nhuận cơ bản từ doanh thu và chi phí',
            example:
                'Ví dụ:\n'
                'Doanh thu: 10,000,000 đ\n'
                'Chi phí: 6,000,000 đ\n'
                'Lợi nhuận = 10,000,000 − 6,000,000 = 4,000,000 đ',
            icon: Icons.monetization_on,
            color: Colors.green,
          ),
          _buildFormulaCardWithWidget(
            title: '2. Tỷ Suất Lợi Nhuận (Profit Margin)',
            formulaWidget: _buildFractionFormula(
              left: 'Tỷ suất lợi nhuận',
              numerator: 'Lợi nhuận',
              denominator: 'Doanh thu',
              suffix: '× 100%',
            ),
            description:
                'Đo lường hiệu quả kinh doanh, cho biết bạn kiếm được bao nhiêu % lợi nhuận từ doanh thu',
            example:
                'Ví dụ:\n'
                'Lợi nhuận: 4,000,000 đ\n'
                'Doanh thu: 10,000,000 đ\n'
                'Tỷ suất lợi nhuận = (4,000,000 / 10,000,000) × 100% = 40%',
            icon: Icons.percent,
            color: Colors.blue,
          ),
          _buildFormulaCardWithWidget(
            title: '3. Giá Vốn Hàng Bán (COGS)',
            formulaWidget: _buildSimpleFormula(
              left: 'Giá vốn',
              operator: '=',
              right: 'Tồn kho đầu tháng + Hàng mua − Tồn kho cuối tháng',
            ),
            description:
                'Chi phí trực tiếp để sản xuất hoặc mua hàng hóa đã bán',
            example:
                'Ví dụ:\n'
                'Tồn kho đầu tháng: 5,000,000 đ\n'
                'Hàng nhập thêm: 8,000,000 đ\n'
                'Tồn kho cuối tháng: 3,000,000 đ\n'
                'Giá vốn = 5,000,000 + 8,000,000 − 3,000,000 = 10,000,000 đ',
            icon: Icons.inventory,
            color: Colors.orange,
          ),
          _buildFormulaCardWithWidget(
            title: '4. Doanh Thu (Revenue)',
            formulaWidget: _buildSimpleFormula(
              left: 'Doanh thu',
              operator: '=',
              right: 'Số lượng bán × Giá bán',
            ),
            description: 'Tổng tiền thu được từ việc bán hàng hóa hoặc dịch vụ',
            example:
                'Ví dụ:\n'
                'Bán 100 sản phẩm\n'
                'Giá bán mỗi sản phẩm: 50,000 đ\n'
                'Doanh thu = 100 × 50,000 = 5,000,000 đ',
            icon: Icons.attach_money,
            color: Colors.teal,
          ),
          _buildFormulaCardWithWidget(
            title: '5. Điểm Hòa Vốn (Break-even Point)',
            formulaWidget: _buildFractionFormula(
              left: 'Điểm hòa vốn',
              numerator: 'Chi phí cố định',
              denominator: 'Giá bán − Chi phí biến đổi',
            ),
            description: 'Số lượng sản phẩm cần bán để không lỗ không lãi',
            example:
                'Ví dụ:\n'
                'Chi phí cố định: 6,000,000 đ/tháng\n'
                'Giá bán: 100,000 đ/sản phẩm\n'
                'Chi phí biến đổi: 40,000 đ/sản phẩm\n'
                'Điểm hòa vốn = 6,000,000 / (100,000 − 40,000) = 100 sản phẩm',
            icon: Icons.balance,
            color: Colors.purple,
          ),
          _buildFormulaCardWithWidget(
            title: '6. Vốn Lưu Động (Working Capital)',
            formulaWidget: _buildSimpleFormula(
              left: 'Vốn lưu động',
              operator: '=',
              right: 'Tài sản ngắn hạn − Nợ ngắn hạn',
            ),
            description:
                'Số tiền có sẵn để sử dụng trong hoạt động kinh doanh hàng ngày',
            example:
                'Ví dụ:\n'
                'Tài sản ngắn hạn: 15,000,000 đ\n'
                '(tiền mặt, hàng tồn kho, phải thu)\n'
                'Nợ ngắn hạn: 8,000,000 đ\n'
                'Vốn lưu động = 15,000,000 − 8,000,000 = 7,000,000 đ',
            icon: Icons.account_balance_wallet,
            color: Colors.indigo,
          ),
          _buildFormulaCardWithWidget(
            title: '7. Tỷ Suất Sinh Lời (ROI)',
            formulaWidget: _buildFractionFormula(
              left: 'ROI',
              numerator: 'Lợi nhuận − Chi phí đầu tư',
              denominator: 'Chi phí đầu tư',
              suffix: '× 100%',
            ),
            description: 'Đo lường hiệu quả của khoản đầu tư',
            example:
                'Ví dụ:\n'
                'Đầu tư: 20,000,000 đ\n'
                'Lợi nhuận thu về: 26,000,000 đ\n'
                'ROI = [(26,000,000 − 20,000,000) / 20,000,000] × 100%\n'
                'ROI = 30%',
            icon: Icons.trending_up,
            color: Colors.red,
          ),
          _buildFormulaCardWithWidget(
            title: '8. Giá Bán Lẻ Đề Xuất',
            formulaWidget: _buildFractionFormula(
              left: 'Giá bán',
              numerator: 'Giá vốn',
              denominator: '1 − Tỷ suất lợi nhuận',
            ),
            description: 'Tính giá bán dựa trên giá vốn và lợi nhuận mong muốn',
            example:
                'Ví dụ:\n'
                'Giá vốn: 60,000 đ\n'
                'Muốn lợi nhuận 40% (0.4)\n'
                'Giá bán = 60,000 / (1 − 0.4) = 60,000 / 0.6 = 100,000 đ',
            icon: Icons.calculate,
            color: Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleFormula({
    required String left,
    required String operator,
    required String right,
  }) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Text(
          left,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          operator,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          right,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFractionFormula({
    required String left,
    required String numerator,
    required String denominator,
    String? suffix,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                left,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '=',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      numerator,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(height: 2, width: 140, color: Colors.blue),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      denominator,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    suffix,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRichTextExample(String example) {
    final lines = example.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // Check if line contains a formula (has = sign)
        if (line.contains('=') && !line.startsWith('Ví dụ:')) {
          final parts = line.split('=');
          if (parts.length == 2) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    parts[0].trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                  const Text(
                    ' = ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      height: 1.6,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      parts[1].trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        }
        // Regular line
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            line,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFormulaCardWithWidget({
    required String title,
    required Widget formulaWidget,
    required String description,
    required String example,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: formulaWidget,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.green,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Ví dụ minh họa',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildRichTextExample(example),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
