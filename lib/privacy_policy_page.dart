import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chính sách bảo mật'),
        backgroundColor: Colors.black26,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              icon: Icons.verified_user,
              title: 'Quyền truy cập',
              content: 'Ứng dụng yêu cầu quyền truy cập kho ảnh khi bạn muốn thêm hình ảnh sản phẩm. Bạn có thể từ chối bất kỳ lúc nào.',
              color: Colors.green,
            ),
            _buildSectionCard(
              icon: Icons.security,
              title: 'Dữ liệu của bạn',
              content: 'Tất cả dữ liệu bán hàng, chi tiêu và kho hàng của bạn được lưu trữ trực tiếp trên thiết bị của bạn. Chúng tôi không gửi dữ liệu này đến máy chủ hoặc bên thứ ba nào. Bạn hoàn toàn kiểm soát và chịu trách nhiệm với dữ liệu của mình.',
              color: Colors.blue,
            ),
            _buildSectionCard(
              icon: Icons.storage,
              title: 'Xuất file dữ liệu CSV và JSON',
              content: 'Ứng dụng cho phép bạn xuất dữ liệu bán hàng, chi tiêu và kho hàng dưới dạng file CSV và JSON để bạn có thể sao lưu hoặc sử dụng trong các ứng dụng khác. Các file này được lưu trong bộ nhớ của thiết bị và hoàn toàn do bạn kiểm soát.',
              color: Colors.orange,
            ),
            _buildSectionCard(
              icon: Icons.delete_forever,
              title: 'Xóa dữ liệu',
              content: 'Bạn có thể xóa tất cả dữ liệu của mình bất kỳ lúc nào thông qua mục "Quản lý Dữ liệu" trong menu.',
              color: Colors.red,
            ),
            _buildSectionCard(
              icon: Icons.email,
              title: 'Liên hệ',
              content: 'Nếu bạn có bất kỳ câu hỏi nào về chính sách bảo mật này, vui lòng liên hệ với chúng tôi.',
              color: Colors.purple,
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Cập nhật lần cuối: Tháng 11, 2025',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: color,
                width: 5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
